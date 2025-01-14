defmodule HygeiaWeb.AutoTracingLive.Clinical do
  @moduledoc false

  use HygeiaWeb, :surface_view

  import HygeiaWeb.Helpers.AutoTracing, only: [get_next_step_route: 1]

  alias Hygeia.AutoTracingContext
  alias Hygeia.AutoTracingContext.AutoTracing
  alias Hygeia.CaseContext
  alias Hygeia.CaseContext.Case
  alias Hygeia.CaseContext.Case.Clinical
  alias Hygeia.CaseContext.Case.Phase.Index
  alias Hygeia.CommunicationContext
  alias Hygeia.Repo
  alias Surface.Components.Form
  alias Surface.Components.Form.ErrorTag
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.Input.InputContext
  alias Surface.Components.Form.Inputs
  alias Surface.Components.Form.RadioButton
  alias Surface.Components.LiveRedirect

  data show_reasons_for_test_help, :boolean, default: false

  @impl Phoenix.LiveView
  def handle_params(%{"case_uuid" => case_uuid} = _params, _uri, socket) do
    case =
      case_uuid
      |> CaseContext.get_case!()
      |> Repo.preload(
        person: [],
        hospitalizations: [organisation: []],
        auto_tracing: [],
        tests: []
      )

    socket =
      cond do
        Case.closed?(case) ->
          raise HygeiaWeb.AutoTracingLive.AutoTracing.CaseClosedError, case_uuid: case.uuid

        !authorized?(case, :auto_tracing, get_auth(socket)) ->
          push_redirect(socket,
            to:
              Routes.auth_login_path(socket, :login,
                person_uuid: case.person_uuid,
                return_url: Routes.auto_tracing_auto_tracing_path(socket, :auto_tracing, case)
              )
          )

        !AutoTracing.step_available?(case.auto_tracing, :clinical) ->
          push_redirect(socket,
            to: Routes.auto_tracing_auto_tracing_path(socket, :auto_tracing, case)
          )

        true ->
          assign(socket,
            case: case,
            changeset: %Ecto.Changeset{
              CaseContext.change_case(case, %{}, %{symptoms_required: true})
              | action: :validate
            },
            auto_tracing: case.auto_tracing
          )
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"case" => case_params}, socket) do
    case_params =
      case_params
      |> Map.put_new("hospitalizations", [])
      |> Map.update("clinical", nil, fn clinical ->
        clinical
        |> Map.put_new("reasons_for_test", [])
        |> Map.put_new("symptom_start", nil)
        |> Map.put_new("symptoms", [])
      end)

    {:noreply,
     assign(
       socket,
       :changeset,
       %Ecto.Changeset{
         CaseContext.change_case(socket.assigns.case, case_params, %{symptoms_required: true})
         | action: :validate
       }
     )}
  end

  def handle_event(
        "add_hospitalization",
        _params,
        %{assigns: %{changeset: changeset, case: case}} = socket
      ) do
    {:noreply,
     assign(
       socket,
       :changeset,
       %Ecto.Changeset{
         CaseContext.change_case(
           case,
           changeset_add_to_params(changeset, :hospitalizations, %{
             uuid: Ecto.UUID.generate()
           }),
           %{symptoms_required: true}
         )
         | action: :validate
       }
     )}
  end

  def handle_event(
        "remove_hospitalization",
        %{"changeset-uuid" => uuid} = _params,
        %{assigns: %{changeset: changeset, case: case}} = socket
      ) do
    {:noreply,
     assign(
       socket,
       :changeset,
       %Ecto.Changeset{
         CaseContext.change_case(
           case,
           changeset_remove_from_params_by_id(changeset, :hospitalizations, %{uuid: uuid}),
           %{symptoms_required: true}
         )
         | action: :validate
       }
     )}
  end

  def handle_event("advance", _params, socket) do
    {:ok, case} =
      CaseContext.update_case(
        %Ecto.Changeset{socket.assigns.changeset | action: nil},
        %{},
        %{symptoms_required: true}
      )

    case = Repo.preload(case, hospitalizations: [], tests: [])

    {phase_start, phase_end, _problems} = index_phase_dates(case)

    changeset =
      case
      |> shorten_phases_before(phase_start)
      |> change_phase_dates(phase_start, phase_end)

    {:ok, case} = CaseContext.update_case(case, changeset)

    :ok = send_notifications(case, socket)

    {:ok, _auto_tracing} =
      AutoTracingContext.advance_one_step(socket.assigns.auto_tracing, :clinical)

    {:noreply,
     push_redirect(socket,
       to: get_next_step_route(:clinical).(socket, socket.assigns.auto_tracing.case_uuid)
     )}
  end

  def handle_event("show_reasons_for_test_help", _params, socket) do
    {:noreply, assign(socket, show_reasons_for_test_help: true)}
  end

  def handle_event("hide_reasons_for_test_help", _params, socket) do
    {:noreply, assign(socket, show_reasons_for_test_help: false)}
  end

  @impl Phoenix.LiveView
  def handle_info(
        {:hospitalisation_change_organisation, uuid, organisation_uuid},
        %{assigns: %{changeset: changeset, case: case}} = socket
      ) do
    {:noreply,
     assign(
       socket,
       :changeset,
       %Ecto.Changeset{
         CaseContext.change_case(
           case,
           changeset_update_params_by_id(
             changeset,
             :hospitalizations,
             %{uuid: uuid},
             &Map.put(&1, "organisation_uuid", organisation_uuid)
           )
         )
         | action: :validate
       }
     )}
  end

  def handle_info(_other, socket), do: {:noreply, socket}

  defp change_phase_dates(changeset, phase_start, phase_end) do
    index_phase =
      Enum.find(
        Ecto.Changeset.fetch_field!(changeset, :phases),
        &match?(%Case.Phase{details: %Index{}}, &1)
      )

    changeset_update_params_by_id(changeset, :phases, %{uuid: index_phase.uuid}, fn params ->
      Map.merge(params, %{
        "quarantine_order" => true,
        "start" => phase_start,
        "end" => phase_end
      })
    end)
  end

  defp shorten_phases_before(case, phase_start) do
    Enum.reduce(case.phases, CaseContext.change_case(case), fn
      %Case.Phase{
        quarantine_order: true,
        uuid: phase_before_uuid,
        start: phase_before_start,
        end: phase_before_end
      },
      acc ->
        case {Date.compare(phase_before_start, phase_start),
              Date.compare(phase_before_end, phase_start)} do
          {:gt, _cmp_end} ->
            CaseContext.change_case(
              acc,
              changeset_update_params_by_id(
                acc,
                :phases,
                %{uuid: phase_before_uuid},
                &Map.merge(&1, %{"end" => nil, "start" => nil, "quarantine_order" => false})
              )
            )

          {_cmp_start, :gt} ->
            CaseContext.change_case(
              acc,
              changeset_update_params_by_id(
                acc,
                :phases,
                %{uuid: phase_before_uuid},
                &Map.merge(&1, %{"end" => phase_start})
              )
            )

          _other ->
            acc
        end

      %Case.Phase{}, acc ->
        acc
    end)
  end

  defp index_phase_dates(case) do
    {start_date, problems} =
      case Case.earliest_self_service_phase_start_date(case, Index) do
        {:corrected, date} -> {date, [:phase_start_date_corrected]}
        {:ok, date} -> {date, []}
      end

    phase_start = Date.utc_today()
    phase_end = Date.add(start_date, Index.default_length_days())

    last_test_date_plus_two =
      case Case.last_positive_test_date(case) do
        nil -> nil
        date -> Date.add(date, 2)
      end

    phase_end =
      [phase_start, last_test_date_plus_two, phase_end]
      |> Enum.reject(&is_nil/1)
      |> Enum.sort({:desc, Date})
      |> List.first()

    {phase_start, phase_end, problems}
  end

  defp send_notifications(case, socket) do
    case = Repo.preload(case, person: [])

    index_phase = Enum.find(case.phases, &match?(%Case.Phase{details: %Index{}}, &1))

    :ok =
      case
      |> CommunicationContext.create_outgoing_sms(isolation_sms(socket, case, index_phase))
      |> case do
        {:ok, _sms} -> :ok
        {:error, :no_mobile_number} -> :ok
        {:error, :sms_config_missing} -> :ok
      end

    :ok =
      case
      |> CommunicationContext.create_outgoing_email(
        isolation_email_subject(),
        isolation_email_body(socket, case, index_phase, :email)
      )
      |> case do
        {:ok, _email} -> :ok
        {:error, :no_email} -> :ok
        {:error, :no_outgoing_mail_configuration} -> :ok
      end
  end
end
