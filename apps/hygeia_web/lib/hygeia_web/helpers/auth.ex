defmodule HygeiaWeb.Helpers.Auth do
  @moduledoc false

  alias Hygeia.UserContext.User

  @spec is_logged_in?(conn_or_socket :: Plug.Conn.t() | Phoenix.LiveView.Socket.t()) :: boolean
  def is_logged_in?(conn_or_socket), do: get_auth(conn_or_socket) != :anonymous

  @spec get_auth(conn_or_socket :: Plug.Conn.t() | Phoenix.LiveView.Socket.t()) :: nil | User.t()
  def get_auth(%Plug.Conn{} = conn), do: Plug.Conn.get_session(conn, :auth) || :anonymous

  def get_auth(%Phoenix.LiveView.Socket{} = socket) do
    socket.private[:conn_session]["auth"] || socket.private[:connect_info][:session]["auth"] ||
      case socket.assigns do
        %{__context__: ctx} -> ctx[{HygeiaWeb, :auth}]
        _other -> :anonymous
      end || :anonymous
  end
end
