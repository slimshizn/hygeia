defmodule HygeiaWeb.CaseLive.CreatePossibleIndex do
  @moduledoc false

  use HygeiaWeb, :surface_view

  import HygeiaWeb.CaseLive.Create

  alias Hygeia.CaseContext
  alias Hygeia.Repo
  alias Hygeia.TenantContext
  alias Hygeia.UserContext
  alias HygeiaWeb.CaseLive.Create.CreatePersonSchema
  alias HygeiaWeb.CaseLive.CreatePossibleIndex.CreateSchema
  alias HygeiaWeb.FormError
  alias Surface.Components.Form
  alias Surface.Components.Form.DateInput
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.Input.InputContext
  alias Surface.Components.Form.Inputs
  alias Surface.Components.Form.Label
  alias Surface.Components.Form.RadioButton
  alias Surface.Components.Form.Select
  alias Surface.Components.Form.TextArea
  alias Surface.Components.Form.TextInput

  @impl Phoenix.LiveView
  def mount(params, session, socket) do
    tenants = TenantContext.list_tenants()
    users = UserContext.list_users()
    auth_user = get_auth(socket)

    super(
      params,
      session,
      assign(socket,
        changeset:
          CreateSchema.changeset(
            %CreateSchema{people: []},
            Map.merge(params, %{
              "default_tracer_uuid" => auth_user.uuid,
              "default_supervisor_uuid" => auth_user.uuid
            })
          ),
        tenants: tenants,
        users: users,
        suspected_duplicate_changeset_uuid: nil,
        file: nil
      )
    )
  end

  @impl Phoenix.LiveView
  def handle_params(params, uri, socket) do
    super(params, uri, assign(socket, suspected_duplicate_changeset_uuid: nil))
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"create_schema" => create_params}, socket) do
    {:noreply,
     socket
     |> assign(:changeset, %{
       CreateSchema.changeset(%CreateSchema{people: []}, create_params)
       | action: :validate
     })
     |> maybe_block_navigation()}
  end

  def handle_event("save", %{"create_schema" => create_params}, socket) do
    %CreateSchema{people: []}
    |> CreateSchema.changeset(create_params)
    |> case do
      %Ecto.Changeset{valid?: false} = changeset ->
        {:noreply,
         socket
         |> assign(changeset: changeset)
         |> maybe_block_navigation()}

      %Ecto.Changeset{valid?: true} = changeset ->
        {:ok, transmissions} =
          Repo.transaction(fn ->
            changeset
            |> Ecto.Changeset.fetch_field!(:people)
            |> Enum.reject(&match?(%CreatePersonSchema{uuid: nil}, &1))
            |> Enum.map(&{&1, save_or_load_person_schema(&1, socket, changeset)})
            |> Enum.map(&create_case(&1, changeset))
            |> Enum.map(&create_transmission(&1, changeset))
          end)

        {:noreply,
         socket
         |> put_flash(
           :info,
           ngettext("Created Case", "Created %{n} Cases", length(transmissions),
             n: length(transmissions)
           )
         )
         |> assign(
           changeset:
             changeset
             |> Ecto.Changeset.put_embed(:people, [])
             |> Map.put(:errors, [])
             |> Map.put(:valid?, true)
             |> CreateSchema.validate_changeset(),
           suspected_duplicate_changeset_uuid: nil,
           file: nil
         )
         |> maybe_block_navigation()}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:upload, data}, socket) do
    send_update(HygeiaWeb.CaseLive.CSVImport, id: "csv-import", data: data)

    {:noreply, socket}
  end

  def handle_info({:csv_import, {:ok, data}}, socket) do
    {:noreply,
     socket
     |> assign(
       changeset: import_into_changeset(socket.assigns.changeset, data, socket.assigns.tenants)
     )
     |> maybe_block_navigation()}
  end

  def handle_info({:csv_import, {:error, _reason}}, socket) do
    {:noreply, put_flash(socket, :error, gettext("Could not parse CSV"))}
  end

  def handle_info({:accept_duplicate, uuid, person}, socket) do
    {:noreply,
     assign(socket,
       changeset: accept_duplicate(socket.assigns.changeset, uuid, person)
     )}
  end

  def handle_info({:declined_duplicate, uuid}, socket) do
    {:noreply, assign(socket, changeset: decline_duplicate(socket.assigns.changeset, uuid))}
  end

  def handle_info({:remove_person, uuid}, socket) do
    {:noreply,
     assign(socket,
       changeset: remove_person(socket.assigns.changeset, uuid)
     )}
  end

  def handle_info(_other, socket), do: {:noreply, socket}

  defp create_case({person_schema, {person, supervisor, tracer}}, changeset) do
    {start_date, end_date} =
      changeset
      |> Ecto.Changeset.get_field(:date, nil)
      |> case do
        nil -> {nil, nil}
        %Date{} = start -> {start, Date.add(start, 11)}
      end

    {:ok, case} =
      CaseContext.create_case(person, %{
        phases: [
          %{
            details: %{
              __type__: :possible_index,
              type: Ecto.Changeset.fetch_field!(changeset, :type)
            },
            start: start_date,
            end: end_date
          }
        ],
        supervisor_uuid: supervisor.uuid,
        tracer_uuid: tracer.uuid,
        clinical: %{
          test: person_schema.test_date,
          laboratory_report: person_schema.test_laboratory_report,
          test_kind: person_schema.test_kind,
          result: person_schema.test_result
        }
      })

    case
  end

  defp create_transmission(case, changeset) do
    {:ok, transmission} =
      CaseContext.create_transmission(%{
        recipient_internal: true,
        recipient_case_uuid: case.uuid,
        infection_place: changeset |> Ecto.Changeset.fetch_field!(:infection_place) |> unpack,
        propagator_internal: Ecto.Changeset.fetch_field!(changeset, :propagator_internal),
        propagator_ims_id: Ecto.Changeset.get_field(changeset, :propagator_ims_id),
        propagator_case_uuid: Ecto.Changeset.get_field(changeset, :propagator_case_uuid)
      })

    transmission
  end

  defp unpack(struct) when is_struct(struct) do
    struct
    |> Map.from_struct()
    |> Enum.map(fn {key, value} -> {key, unpack(value)} end)
    |> Map.new()
  end

  defp unpack(other), do: other

  defp maybe_block_navigation(%{assigns: %{changeset: changeset}} = socket) do
    changeset
    |> Ecto.Changeset.get_field(:people, [])
    |> case do
      [] -> push_event(socket, "unblock_navigation", %{})
      [_] -> push_event(socket, "unblock_navigation", %{})
      [_ | _] -> push_event(socket, "block_navigation", %{})
    end
  end
end
