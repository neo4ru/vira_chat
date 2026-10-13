defmodule ViraChatWeb.AdminLive.Users do
  use ViraChatWeb, :live_view
  import ViraChatWeb.AdminComponents
  alias ViraChat.Admin

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_user, socket.assigns.current_scope.user)
     |> assign(:search, "")
     |> assign(:users, Admin.list_users())}
  end

  @impl true
  def handle_event("search", %{"value" => value}, socket) do
    {:noreply,
     socket
     |> assign(:search, value)
     |> assign(:users, Admin.list_users(value))}
  end

  @impl true
  def handle_event("change_role", %{"user_id" => id, "role" => role}, socket) do
    user = Admin.get_user!(id)
    actor = socket.assigns.current_user

    case Admin.change_role(user, role, actor) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:users, Admin.list_users(socket.assigns.search))
         |> put_flash(:info, "Role updated")}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "Only superusers can change roles")}

      {:error, :cannot_demote_self} ->
        {:noreply, put_flash(socket, :error, "You cannot demote yourself")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update role")}
    end
  end

  @impl true
  def handle_event("ban", %{"id" => id}, socket) do
    user = Admin.get_user!(id)
    actor = socket.assigns.current_user

    if user.id == actor.id do
      {:noreply, put_flash(socket, :error, "You cannot ban yourself")}
    else
      Admin.ban_user(user, actor)
      {:noreply, assign(socket, :users, Admin.list_users(socket.assigns.search))}
    end
  end

  @impl true
  def handle_event("unban", %{"id" => id}, socket) do
    user = Admin.get_user!(id)
    actor = socket.assigns.current_user

    Admin.unban_user(user, actor)
    {:noreply, assign(socket, :users, Admin.list_users(socket.assigns.search))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = Admin.get_user!(id)
    actor = socket.assigns.current_user

    if user.id == actor.id do
      {:noreply, put_flash(socket, :error, "You cannot delete yourself")}
    else
      Admin.delete_user(user, actor)

      {:noreply,
       socket
       |> assign(:users, Admin.list_users(socket.assigns.search))
       |> put_flash(:info, "User deleted")}
    end
  end
end
