defmodule HygeiaWeb.StatisticsLive.ChooseTenant do
  @moduledoc false

  use HygeiaWeb, :surface_view

  alias Hygeia.TenantContext
  alias Hygeia.TenantContext.Tenant
  alias Surface.Components.LiveRedirect

  @impl Phoenix.LiveView
  def mount(params, session, socket) do
    socket =
      if authorized?(Tenant, :list, get_auth(socket)) do
        assign(socket, :tenants, list_tenants())
      else
        socket
        |> push_redirect(to: Routes.home_path(socket, :index))
        |> put_flash(:error, gettext("You are not authorized to do this action."))
      end

    super(params, session, socket)
  end

  @impl Phoenix.LiveView
  def handle_info(_other, socket), do: {:noreply, socket}

  defp list_tenants, do: TenantContext.list_tenants()
end
