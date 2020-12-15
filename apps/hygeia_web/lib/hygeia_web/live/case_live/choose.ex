defmodule HygeiaWeb.CaseLive.Choose do
  @moduledoc false

  use HygeiaWeb, :surface_live_component

  import Ecto.Query

  alias Hygeia.CaseContext
  alias Hygeia.CaseContext.Case
  alias Hygeia.Repo
  alias Hygeia.TenantContext
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.Input.InputContext

  @doc "An identifier for the form"
  prop form, :form

  @doc "An identifier for the associated field"
  prop field, :atom

  prop change, :event

  data modal_open, :boolean, default: false
  data query, :string, default: ""
  data tenants, :list, default: nil

  @impl Phoenix.LiveComponent
  def handle_event("open_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(
       modal_open: true,
       tenants:
         case socket.assigns.tenants do
           nil ->
             Enum.filter(
               TenantContext.list_tenants(),
               &authorized?(Case, :list, get_auth(socket), tenant: &1)
             )

           list when is_list(list) ->
             list
         end
     )
     |> load_cases}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, modal_open: false)}
  end

  def handle_event("query", %{"value" => value} = _params, socket) do
    socket =
      socket
      |> assign(query: value)
      |> load_cases

    {:noreply, socket}
  end

  defp load_cases(socket) do
    query =
      if socket.assigns.query in [nil, ""] do
        Case
      else
        CaseContext.fulltext_case_search_query(socket.assigns.query)
      end

    cases =
      Repo.all(
        from(case in query,
          where: case.tenant_uuid in ^Enum.map(socket.assigns.tenants, & &1.uuid)
        )
      )

    assign(socket, cases: Repo.preload(cases, person: [tenant: []]))
  end

  defp load_case(uuid), do: uuid |> CaseContext.get_case!() |> Repo.preload(person: [tenant: []])
end
