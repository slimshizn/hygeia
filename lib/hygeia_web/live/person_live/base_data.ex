defmodule HygeiaWeb.PersonLive.BaseData do
  @moduledoc false

  use HygeiaWeb, :surface_view

  import Ecto.Changeset

  alias Hygeia.CaseContext
  alias Hygeia.CaseContext.Address
  alias Hygeia.CaseContext.Case
  alias Hygeia.CaseContext.Person
  alias Hygeia.EctoType.NOGA
  alias Hygeia.Helpers.Empty
  alias Hygeia.OrganisationContext
  alias Hygeia.OrganisationContext.Affiliation.Kind
  alias Hygeia.Repo
  alias Hygeia.TenantContext
  alias HygeiaWeb.DateInput
  alias Surface.Components.Form
  alias Surface.Components.Form.ErrorTag
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.Input.InputContext
  alias Surface.Components.Form.Inputs
  alias Surface.Components.Form.RadioButton
  alias Surface.Components.Form.Select
  alias Surface.Components.Form.TextArea
  alias Surface.Components.Form.TextInput
  alias Surface.Components.Link
  alias Surface.Components.LivePatch

  data show_reidentification_modal, :boolean, default: false

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _uri, socket) do
    person = CaseContext.get_person!(id)

    action =
      case socket.assigns.live_action do
        :edit -> :update
        :show -> :details
      end

    socket =
      if authorized?(person, action, get_auth(socket)) do
        Phoenix.PubSub.subscribe(Hygeia.PubSub, "people:#{id}")

        tenants =
          Enum.filter(
            TenantContext.list_tenants(),
            &authorized?(person, :create, get_auth(socket), tenant: &1)
          )

        socket
        |> assign(
          tenants: tenants,
          page_title: "#{person.first_name} #{person.last_name} - #{gettext("Person")}"
        )
        |> load_data(person)
      else
        socket
        |> push_redirect(to: Routes.home_index_path(socket, :index))
        |> put_flash(:error, gettext("You are not authorized to do this action."))
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:updated, %Person{} = person, _version}, socket) do
    {:noreply, load_data(socket, person)}
  end

  def handle_info({:deleted, %Person{}, _version}, socket) do
    {:noreply, redirect(socket, to: Routes.person_index_path(socket, :index))}
  end

  def handle_info(_other, socket), do: {:noreply, socket}

  @impl Phoenix.LiveView
  def handle_event("reset", _params, socket) do
    person = CaseContext.get_person!(socket.assigns.person.uuid)

    {:noreply,
     socket
     |> load_data(socket.assigns.person)
     |> push_patch(to: Routes.person_base_data_path(socket, :show, person))
     |> maybe_block_navigation()}
  end

  def handle_event("validate", %{"person" => person_params}, socket) do
    person_params =
      person_params
      |> Map.put_new("affiliations", [])
      |> Map.put_new("contact_methods", [])
      |> Map.put_new("external_references", [])
      |> Map.put_new("vaccination_shots", [])

    {:noreply,
     socket
     |> assign(:changeset, %{
       CaseContext.change_person(socket.assigns.person, person_params)
       | action: :validate
     })
     |> maybe_block_navigation()}
  end

  def handle_event(
        "add_contact_method",
        _params,
        %{assigns: %{changeset: changeset, person: person}} = socket
      ) do
    {:noreply,
     socket
     |> assign(
       :changeset,
       CaseContext.change_person(
         person,
         changeset_add_to_params(changeset, :contact_methods, %{uuid: Ecto.UUID.generate()})
       )
     )
     |> maybe_block_navigation()}
  end

  def handle_event(
        "remove_contact_method",
        %{"uuid" => uuid} = _params,
        %{assigns: %{changeset: changeset, person: person}} = socket
      ) do
    {:noreply,
     socket
     |> assign(
       :changeset,
       CaseContext.change_person(
         person,
         changeset_remove_from_params_by_id(changeset, :contact_methods, %{uuid: uuid})
       )
     )
     |> maybe_block_navigation()}
  end

  def handle_event(
        "add_external_reference",
        _params,
        %{assigns: %{changeset: changeset, person: person}} = socket
      ) do
    {:noreply,
     socket
     |> assign(
       :changeset,
       CaseContext.change_person(
         person,
         changeset_add_to_params(changeset, :external_references, %{uuid: Ecto.UUID.generate()})
       )
     )
     |> maybe_block_navigation()}
  end

  def handle_event(
        "remove_external_reference",
        %{"uuid" => uuid} = _params,
        %{assigns: %{changeset: changeset, person: person}} = socket
      ) do
    {:noreply,
     socket
     |> assign(
       :changeset,
       CaseContext.change_person(
         person,
         changeset_remove_from_params_by_id(changeset, :external_references, %{uuid: uuid})
       )
     )
     |> maybe_block_navigation()}
  end

  def handle_event(
        "add_affiliation",
        _params,
        %{assigns: %{changeset: changeset, person: person}} = socket
      ) do
    {:noreply,
     socket
     |> assign(
       :changeset,
       CaseContext.change_person(
         person,
         changeset_add_to_params(changeset, :affiliations, %{uuid: Ecto.UUID.generate()})
       )
     )
     |> maybe_block_navigation()}
  end

  def handle_event(
        "remove_affiliation",
        %{"uuid" => uuid} = _params,
        %{assigns: %{changeset: changeset, person: person}} = socket
      ) do
    {:noreply,
     socket
     |> assign(
       :changeset,
       CaseContext.change_person(
         person,
         changeset_remove_from_params_by_id(changeset, :affiliations, %{uuid: uuid})
       )
     )
     |> maybe_block_navigation()}
  end

  def handle_event(
        "select_affiliation_organisation",
        %{"subject" => affiliation_uuid} = params,
        %{assigns: %{changeset: changeset, person: person}} = socket
      ) do
    {:noreply,
     socket
     |> assign(
       :changeset,
       CaseContext.change_person(
         person,
         changeset_update_params_by_id(
           changeset,
           :affiliations,
           %{uuid: affiliation_uuid},
           &Map.put(&1, "organisation_uuid", params["uuid"])
         )
       )
     )
     |> maybe_block_navigation()}
  end

  def handle_event(
        "select_affiliation_division",
        %{"subject" => affiliation_uuid} = params,
        %{assigns: %{changeset: changeset, person: person}} = socket
      ) do
    {:noreply,
     socket
     |> assign(
       :changeset,
       CaseContext.change_person(
         person,
         changeset_update_params_by_id(
           changeset,
           :affiliations,
           %{uuid: affiliation_uuid},
           &Map.put(&1, "division_uuid", params["uuid"])
         )
       )
     )
     |> maybe_block_navigation()}
  end

  def handle_event(
        "add_vaccination_shot",
        _params,
        %{assigns: %{changeset: changeset, person: person}} = socket
      ) do
    {:noreply,
     socket
     |> assign(
       changeset: %Ecto.Changeset{
         CaseContext.change_person(
           person,
           changeset_add_to_params(changeset, :vaccination_shots, %{
             uuid: Ecto.UUID.generate()
           })
         )
         | action: :validate
       }
     )
     |> maybe_block_navigation()}
  end

  def handle_event(
        "remove_vaccination_shot",
        %{"uuid" => uuid} = _params,
        %{assigns: %{changeset: changeset, person: person}} = socket
      ) do
    {:noreply,
     socket
     |> assign(
       :changeset,
       %Ecto.Changeset{
         CaseContext.change_person(
           person,
           changeset_remove_from_params_by_id(changeset, :vaccination_shots, %{uuid: uuid})
         )
         | action: :validate
       }
     )
     |> maybe_block_navigation()}
  end

  def handle_event("save", %{"person" => person_params}, socket) do
    true = authorized?(socket.assigns.person, :update, get_auth(socket))

    person_params =
      person_params
      |> Map.put_new("affiliations", [])
      |> Map.put_new("contact_methods", [])
      |> Map.put_new("external_references", [])
      |> Map.put_new("vaccination_shots", [])

    socket.assigns.person
    |> CaseContext.update_person(person_params)
    |> case do
      {:ok, person} ->
        :ok =
          Enum.each(person.affiliations, fn affiliation ->
            OrganisationContext.propagate_organisation_and_division(affiliation)
          end)

        {:noreply,
         socket
         |> load_data(person)
         |> put_flash(:info, gettext("Person updated successfully"))
         |> push_patch(to: Routes.person_base_data_path(socket, :show, person))}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(changeset: changeset)
         |> maybe_block_navigation()}
    end
  end

  def handle_event("anonymize", _params, %{assigns: %{person: person}} = socket) do
    true = authorized?(person, :update, get_auth(socket))

    socket =
      person
      |> CaseContext.anonymize_person()
      |> case do
        {:ok, _person} ->
          put_flash(socket, :info, pgettext("Person Base Data", "Person anonymized successfully"))

        {:error, :not_anonymized_case} ->
          put_flash(
            socket,
            :error,
            pgettext(
              "Person Base Data",
              "This person can not be anonymized because there are not anonymized cases associated to it"
            )
          )

        _else ->
          put_flash(
            socket,
            :error,
            pgettext(
              "Person Base Data",
              "An unexpected error occurred while anonymizing the person"
            )
          )
      end

    {:noreply, push_redirect(socket, to: Routes.person_base_data_path(socket, :show, person))}
  end

  def handle_event(
        "reidentify",
        %{"person" => %{"first_name" => first_name, "last_name" => last_name}},
        %{assigns: %{person: person}} = socket
      ) do
    true = authorized?(person, :create, get_auth(socket))

    {:ok, _person} = CaseContext.reidentify_person(person, first_name, last_name)

    {:noreply,
     socket
     |> assign(show_reidentification_modal: false)
     |> put_flash(:info, pgettext("Person Base Data", "Person reidentified successfully"))
     |> push_redirect(to: Routes.person_base_data_path(socket, :show, person))}
  end

  def handle_event("delete", _params, %{assigns: %{person: person}} = socket) do
    true = authorized?(person, :delete, get_auth(socket))

    {:ok, _} = CaseContext.delete_person(person)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Person deleted successfully"))
     |> redirect(to: Routes.person_index_path(socket, :index))}
  end

  def handle_event("show_reidentification_modal", _params, socket) do
    {:noreply, assign(socket, show_reidentification_modal: true)}
  end

  def handle_event("hide_reidentification_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(show_reidentification_modal: false)
     |> assign(
       :changeset,
       CaseContext.change_person(socket.assigns.person, %{})
     )}
  end

  defp load_data(socket, person) do
    person =
      Repo.preload(
        person,
        [
          cases: [],
          tenant: [],
          affiliations: [],
          vaccination_shots: [],
          vaccination_shot_validities: []
        ],
        force: true
      )

    changeset = CaseContext.change_person(person, %{})

    socket
    |> assign(person: person, changeset: changeset)
    |> maybe_block_navigation()
  end

  defp load_people_by_id(ids) do
    CaseContext.list_people_by_ids(ids)
  end

  defp load_organisation(id), do: OrganisationContext.get_organisation!(id)

  defp maybe_block_navigation(%{assigns: %{changeset: changeset}} = socket) do
    if Empty.is_empty?(changeset, [:suspected_duplicates_uuid]) do
      push_event(socket, "unblock_navigation", %{})
    else
      push_event(socket, "block_navigation", %{})
    end
  end
end
