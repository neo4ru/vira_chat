defmodule ViraChatWeb.UserAuth do
  use ViraChatWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias ViraChat.Accounts
  alias ViraChat.Accounts.Scope
  alias ViraChat.Accounts.User

  # Make the remember me cookie valid for 14 days.
  @max_age 60 * 60 * 24 * 14

  @remember_me_cookie "_vira_chat_web_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  @doc """
  Logs the user in.
  """
  def log_in_user(conn, user, params \\ %{}) do
    token = Accounts.generate_user_session_token(user)
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      ViraChatWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/")
  end

  @doc """
  Broadcasts a "disconnect" message to all LiveView sessions using the given tokens.

  Called after a magic-link login (or any login method that invalidates older
  sessions) so any other open tabs of this user get logged out cleanly.
  """
  def disconnect_sessions(tokens) when is_list(tokens) do
    for token <- tokens do
      ViraChatWeb.Endpoint.broadcast(
        "users_sessions:#{Base.url_encode64(token)}",
        "disconnect",
        %{}
      )
    end

    :ok
  end

  def disconnect_sessions(_), do: :ok

  @doc """
  Fetches the current scope for the current user.
  """
  def fetch_current_scope_for_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)

    user =
      case user_token && Accounts.get_user_by_session_token(user_token) do
        {user, _authenticated_at} -> user
        _ -> nil
      end

    assign(conn, :current_scope, Scope.for_user(user))
  end

  defp ensure_user_token(conn) do
    if user_token = get_session(conn, :user_token) do
      {user_token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if user_token = conn.cookies[@remember_me_cookie] do
        {user_token, put_session(conn, :user_token, user_token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Redirects the user if already authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_scope] && conn.assigns.current_scope.user do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Requires the user to be authenticated and not banned.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_scope] && conn.assigns.current_scope.user do
      user = conn.assigns.current_scope.user

      if user.banned_at do
        conn
        |> put_flash(:error, "Your account has been suspended.")
        |> redirect(to: ~p"/users/log-in")
        |> halt()
      else
        conn
      end
    else
      conn
      |> maybe_store_return_to()
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: ~p"/users/log-in")
      |> halt()
    end
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  @doc """
  LiveView on_mount hooks.
  """
  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:require_authenticated, _params, _session, socket) do
    case socket.assigns.current_scope do
      %{user: %User{banned_at: banned}} when not is_nil(banned) ->
        {:halt,
         socket
         |> Phoenix.LiveView.put_flash(:error, "Your account has been suspended.")
         |> Phoenix.LiveView.redirect(to: ~p"/users/log-in")}

      %{user: %User{}} ->
        {:cont, socket}

      _ ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/users/log-in")}
    end
  end

  def on_mount(:require_admin, _params, _session, socket) do
    case socket.assigns.current_scope do
      %{user: %User{banned_at: banned}} when not is_nil(banned) ->
        {:halt,
         socket
         |> Phoenix.LiveView.put_flash(:error, "Your account has been suspended.")
         |> Phoenix.LiveView.redirect(to: ~p"/users/log-in")}

      %{user: %User{} = user} ->
        if User.admin?(user) do
          {:cont, socket}
        else
          {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/chat")}
        end

      _ ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/users/log-in")}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, _session, socket) do
    case socket.assigns.current_scope do
      %{user: %User{}} ->
        {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}

      _ ->
        {:cont, socket}
    end
  end

  defp mount_current_scope(socket, session) do
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      user =
        case session["user_token"] && Accounts.get_user_by_session_token(session["user_token"]) do
          {user, _authenticated_at} -> user
          _ -> nil
        end

      Scope.for_user(user)
    end)
  end

  defp signed_in_path(_conn), do: ~p"/chat"
end
