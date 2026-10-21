defmodule ViraChatWeb.UserLive.ResetPassword do
  use ViraChatWeb, :live_view

  alias ViraChat.Accounts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Accounts.get_user_by_reset_password_token(token) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Reset password link is invalid or it has expired.")
         |> push_navigate(to: ~p"/users/log-in")}

      user ->
        changeset = Accounts.change_user_password(user, %{}, hash_password: false)

        {:ok,
         socket
         |> assign(:user, user)
         |> assign(:form, to_form(changeset))
         |> assign(:page_title, "Choose a new password")}
    end
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:user, nil)
     |> assign(:form, to_form(%{"email" => ""}, as: "user"))
     |> assign(:page_title, "Reset your password")}
  end

  @impl true
  def handle_event("validate_email", %{"user" => user_params}, socket) do
    {:noreply, assign(socket, :form, to_form(user_params, as: "user"))}
  end

  def handle_event("submit", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset-password/#{&1}")
      )
    end

    {:noreply,
     socket
     |> put_flash(
       :info,
       "If your email is in our system, you will receive reset instructions shortly."
     )
     |> push_navigate(to: ~p"/users/log-in")}
  end

  def handle_event("validate_password", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.reset_user_password(socket.assigns.user, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password reset successfully. Please log in.")
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
