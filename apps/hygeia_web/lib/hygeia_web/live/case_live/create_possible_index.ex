defmodule HygeiaWeb.CaseLive.CreatePossibleIndex do
  @moduledoc false

  use HygeiaWeb, :surface_view

  import HygeiaWeb.CaseLive.Create

  alias Hygeia.CaseContext
  alias Hygeia.CaseContext.Case
  alias Hygeia.CaseContext.PossibleIndexSubmission
  alias Hygeia.Repo
  alias Hygeia.TenantContext
  alias Hygeia.UserContext
  alias HygeiaWeb.CaseLive.CreatePossibleIndex.CreateSchema
  alias Surface.Components.Form
  alias Surface.Components.Form.Checkbox
  alias Surface.Components.Form.DateInput
  alias Surface.Components.Form.ErrorTag
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.Input.InputContext
  alias Surface.Components.Form.Inputs
  alias Surface.Components.Form.Label
  alias Surface.Components.Form.RadioButton
  alias Surface.Components.Form.Select
  alias Surface.Components.Form.TextInput

  @impl Phoenix.LiveView
  # credo:disable-for-next-line Credo.Check.Design.DuplicatedCode
  def mount(params, session, socket) do
    socket =
      if authorized?(Case, :create, get_auth(socket), tenant: :any) do
        tenants =
          Enum.filter(
            TenantContext.list_tenants(),
            &authorized?(Case, :create, get_auth(socket), tenant: &1)
          )

        supervisor_users = UserContext.list_users_with_role(:supervisor, tenants)
        tracer_users = UserContext.list_users_with_role(:tracer, tenants)

        infection_place_types = CaseContext.list_infection_place_types()
        auth_user = get_auth(socket)

        changeset_attrs =
          params
          |> Map.put_new("default_tracer_uuid", auth_user.uuid)
          |> Map.put_new("default_supervisor_uuid", auth_user.uuid)
          |> Map.put_new("default_country", "CH")

        changeset_attrs =
          case params["possible_index_submission_uuid"] do
            nil -> changeset_attrs
            uuid -> Map.merge(changeset_attrs, possible_index_submission_attrs(uuid))
          end

        assign(socket,
          changeset: CreateSchema.changeset(%CreateSchema{people: []}, changeset_attrs),
          tenants: tenants,
          supervisor_users: supervisor_users,
          tracer_users: tracer_users,
          infection_place_types: infection_place_types,
          suspected_duplicate_changeset_uuid: nil,
          file: nil,
          return_to: params["return_to"],
          loading: false
        )
      else
        socket
        |> push_redirect(to: Routes.home_path(socket, :index))
        |> put_flash(:error, gettext("You are not authorized to do this action."))
      end

    super(params, session, socket)
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
        propagator_case =
          case Ecto.Changeset.fetch_field!(changeset, :propagator_case_uuid) do
            nil -> nil
            id -> CaseContext.get_case!(id)
          end

        {:ok, {cases, transmissions}} =
          Repo.transaction(fn ->
            cases =
              changeset
              |> CreateSchema.drop_empty_rows()
              |> Ecto.Changeset.fetch_field!(:people)
              |> Enum.map(
                &{&1, save_or_load_person_schema(&1, socket, changeset, propagator_case)}
              )
              |> Enum.map(&create_case(&1, changeset))

            transmissions = Enum.map(cases, &create_transmission(&1, changeset))

            changeset
            |> Ecto.Changeset.fetch_field!(:possible_index_submission_uuid)
            |> case do
              nil ->
                :ok

              uuid ->
                {:ok, _possible_index_submission} =
                  uuid
                  |> CaseContext.get_possible_index_submission!()
                  |> CaseContext.delete_possible_index_submission()

                :ok
            end

            {cases, transmissions}
          end)

        send_confirmation_sms(socket, changeset, cases)

        send_confirmation_emails(socket, changeset, cases)

        socket =
          put_flash(
            socket,
            :info,
            ngettext("Created Case", "Created %{n} Cases", length(transmissions),
              n: length(transmissions)
            )
          )

        {:noreply, socket |> handle_save_success(CreateSchema) |> maybe_block_navigation()}
    end
  end

  def handle_event("change_propagator_case", params, socket) do
    {:noreply,
     socket
     |> assign(:changeset, %{
       CreateSchema.changeset(
         %CreateSchema{people: []},
         Map.put(socket.assigns.changeset.params, "propagator_case_uuid", params["uuid"])
       )
       | action: :validate
     })
     |> maybe_block_navigation()}
  end

  @impl Phoenix.LiveView
  def handle_info({:csv_import, :start}, socket) do
    {:noreply, assign(socket, loading: true)}
  end

  def handle_info({:csv_import, {:ok, data}}, socket) do
    {:noreply,
     socket
     |> assign(changeset: import_into_changeset(socket.assigns.changeset, data), loading: false)
     |> maybe_block_navigation()}
  end

  def handle_info({:csv_import, {:error, _reason}}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, gettext("Could not parse CSV"))
     |> assign(loading: false)}
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

  defp possible_index_submission_attrs(uuid) do
    %PossibleIndexSubmission{
      case_uuid: case_uuid,
      transmission_date: transmission_date,
      infection_place: infection_place,
      first_name: first_name,
      last_name: last_name,
      sex: sex,
      mobile: mobile,
      landline: landline,
      email: email,
      address: address
    } = CaseContext.get_possible_index_submission!(uuid)

    %{
      "propagator_internal" => true,
      "propagator_case_uuid" => case_uuid,
      "type" => :contact_person,
      "date" => Date.to_iso8601(transmission_date),
      "infection_place" =>
        infection_place
        |> Map.from_struct()
        |> Map.put(:address, Map.from_struct(infection_place.address))
        |> Map.drop([:type]),
      "people" => [
        %{
          first_name: first_name,
          last_name: last_name,
          sex: sex,
          mobile: mobile,
          landline: landline,
          email: email,
          address: Map.from_struct(address)
        }
      ]
    }
  end

  defp create_case({_person_schema, {person, supervisor, tracer}}, changeset) do
    {start_date, end_date} =
      changeset
      |> Ecto.Changeset.get_field(:date, nil)
      |> case do
        nil ->
          {nil, nil}

        %Date{} = contact_date ->
          start_date = Date.add(contact_date, 1)
          end_date = Date.add(start_date, 8)

          start_date =
            if Date.compare(start_date, Date.utc_today()) == :lt do
              Date.utc_today()
            else
              start_date
            end

          end_date =
            if Date.compare(end_date, Date.utc_today()) == :lt do
              Date.utc_today()
            else
              end_date
            end

          {start_date, end_date}
      end

    {:ok, case} =
      CaseContext.create_case(person, %{
        status:
          if(Ecto.Changeset.fetch_field!(changeset, :directly_close_cases),
            do: :done,
            else: :first_contact
          ),
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
        tracer_uuid: tracer.uuid
      })

    case
  end

  defp send_confirmation_emails(socket, changeset, cases) do
    locale = Gettext.get_locale(HygeiaGettext)

    if Ecto.Changeset.fetch_field!(changeset, :send_confirmation_email) do
      [] =
        cases
        |> Enum.map(
          &Task.async(fn ->
            %Case{phases: [phase]} = &1

            Gettext.put_locale(HygeiaGettext, locale)

            CaseContext.case_send_email(
              &1,
              quarantine_email_subject(),
              quarantine_email_body(socket, &1, phase)
            )
          end)
        )
        |> Enum.map(&Task.await/1)
        |> Enum.reject(&match?({:ok, _}, &1))
        |> Enum.reject(&match?({:error, :no_email}, &1))
        |> Enum.reject(&match?({:error, :no_outgoing_mail_configuration}, &1))
    end
  end

  defp send_confirmation_sms(socket, changeset, cases) do
    locale = Gettext.get_locale(HygeiaGettext)

    if Ecto.Changeset.fetch_field!(changeset, :send_confirmation_sms) do
      [] =
        cases
        |> Enum.map(
          &Task.async(fn ->
            %Case{phases: [phase]} = &1

            Gettext.put_locale(HygeiaGettext, locale)

            CaseContext.case_send_sms(&1, quarantine_sms(socket, &1, phase))
          end)
        )
        |> Enum.map(&Task.await/1)
        |> Enum.reject(&match?({:ok, _}, &1))
        |> Enum.reject(&match?({:error, :no_mobile_number}, &1))
        |> Enum.reject(&match?({:error, :sms_config_missing}, &1))
    end
  end

  defp create_transmission(case, changeset) do
    {:ok, transmission} =
      CaseContext.create_transmission(%{
        date: Ecto.Changeset.get_field(changeset, :date),
        recipient_internal: true,
        recipient_case_uuid: case.uuid,
        infection_place: changeset |> Ecto.Changeset.fetch_field!(:infection_place) |> unpack,
        propagator_internal: Ecto.Changeset.fetch_field!(changeset, :propagator_internal),
        propagator_ism_id: Ecto.Changeset.get_field(changeset, :propagator_ism_id),
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
