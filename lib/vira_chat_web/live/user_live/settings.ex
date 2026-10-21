defmodule ViraChatWeb.UserLive.Settings do
  use ViraChatWeb, :live_view

  on_mount {ViraChatWeb.UserAuth, :require_sudo_mode}

  alias ViraChat.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-surface pb-16 dark:bg-[#0b0b0d]">
        <div class="mx-auto max-w-2xl px-4 py-6 sm:px-6">
          <div class="mb-4 flex items-center justify-between">
            <.link
              navigate={~p"/users/profile"}
              class="flex items-center gap-2 text-[13px] font-medium text-body transition hover:text-brand"
            >
              <.icon name="hero-arrow-left" class="size-4" /> Back to profile
            </.link>
            <.link
              navigate={~p"/chat"}
              class="text-[13px] font-medium text-body transition hover:text-brand"
            >
              Open chats
            </.link>
          </div>

          <h1 class="text-[22px] font-bold tracking-tight text-ink dark:text-white">
            Account settings
          </h1>
          <p class="mt-1 text-[13px] text-body">
            Manage the email address and password for your account.
          </p>

          <div class="mt-5 rounded-2xl border border-line bg-white p-5 dark:border-[#242424] dark:bg-[#141414]">
            <div class="flex items-start gap-3">
              <div class="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-xl bg-brand-soft text-brand dark:bg-[#1b1530]">
                <.icon name="hero-envelope" class="size-4" />
              </div>
              <div class="min-w-0">
                <h2 class="text-[14px] font-bold text-ink dark:text-white">Email address</h2>
                <p class="text-[12px] text-body">
                  Current: <span class="font-medium text-ink dark:text-[#d8dfeb]">{@current_email}</span>
                </p>
              </div>
            </div>

            <.form
              for={@email_form}
              id="email_form"
              phx-submit="update_email"
              phx-change="validate_email"
              class="mt-4 space-y-3"
            >
              <div>
                <label
                  for={@email_form[:email].id}
                  class="mb-1.5 block text-[12px] font-semibold text-ink dark:text-white"
                >
                  New email address
                </label>
                <input
                  type="email"
                  name={@email_form[:email].name}
                  id={@email_form[:email].id}
                  value={@email_form[:email].value}
                  required
                  autocomplete="username"
                  spellcheck="false"
                  class="w-full rounded-xl border border-line bg-surface-2 px-3.5 py-2.5 text-[13px] text-ink outline-none transition placeholder:text-muted focus:border-brand/40 focus:bg-white focus:ring-2 focus:ring-brand/15 dark:border-[#2a2a2a] dark:bg-[#161616] dark:text-white dark:focus:bg-[#111]"
                />
                <%= for {message, _opts} <- @email_form[:email].errors do %>
                  <p class="mt-1 text-[11px] font-medium text-danger">{message}</p>
                <% end %>
              </div>

              <button
                type="submit"
                phx-disable-with="Changing..."
                class="flex items-center gap-2 rounded-xl bg-brand px-5 py-2.5 text-[12.5px] font-semibold text-white shadow-sm shadow-brand/30 transition hover:bg-brand-600 disabled:opacity-60"
              >
                <.icon name="hero-check" class="size-4" /> Change Email
              </button>
            </.form>
          </div>

          <div class="mt-4 rounded-2xl border border-line bg-white p-5 dark:border-[#242424] dark:bg-[#141414]">
            <div class="flex items-start gap-3">
              <div class="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-xl bg-brand-soft text-brand dark:bg-[#1b1530]">
                <.icon name="hero-lock-closed" class="size-4" />
              </div>
              <div class="min-w-0">
                <h2 class="text-[14px] font-bold text-ink dark:text-white">Password</h2>
                <p class="text-[12px] text-body">
                  Use at least 12 characters. Changing it signs out other sessions.
                </p>
              </div>
            </div>

            <.form
              for={@password_form}
              id="password_form"
              action={~p"/users/update-password"}
              method="post"
              phx-change="validate_password"
              phx-submit="update_password"
              phx-trigger-action={@trigger_submit}
              class="mt-4 space-y-3"
            >
              <input
                name={@password_form[:email].name}
                type="hidden"
                id="hidden_user_email"
                spellcheck="false"
                value={@current_email}
              />

              <div>
                <label
                  for={@password_form[:password].id}
                  class="mb-1.5 block text-[12px] font-semibold text-ink dark:text-white"
                >
                  New password
                </label>
                <input
                  type="password"
                  name={@password_form[:password].name}
                  id={@password_form[:password].id}
                  autocomplete="new-password"
                  spellcheck="false"
                  required
                  class="w-full rounded-xl border border-line bg-surface-2 px-3.5 py-2.5 text-[13px] text-ink outline-none transition focus:border-brand/40 focus:bg-white focus:ring-2 focus:ring-brand/15 dark:border-[#2a2a2a] dark:bg-[#161616] dark:text-white dark:focus:bg-[#111]"
                />
                <%= for {message, _opts} <- @password_form[:password].errors do %>
                  <p class="mt-1 text-[11px] font-medium text-danger">{message}</p>
                <% end %>
              </div>

              <div>
                <label
                  for={@password_form[:password_confirmation].id}
                  class="mb-1.5 block text-[12px] font-semibold text-ink dark:text-white"
                >
                  Confirm new password
                </label>
                <input
                  type="password"
                  name={@password_form[:password_confirmation].name}
                  id={@password_form[:password_confirmation].id}
                  autocomplete="new-password"
                  spellcheck="false"
                  class="w-full rounded-xl border border-line bg-surface-2 px-3.5 py-2.5 text-[13px] text-ink outline-none transition focus:border-brand/40 focus:bg-white focus:ring-2 focus:ring-brand/15 dark:border-[#2a2a2a] dark:bg-[#161616] dark:text-white dark:focus:bg-[#111]"
                />
                <%= for {message, _opts} <- @password_form[:password_confirmation].errors do %>
                  <p class="mt-1 text-[11px] font-medium text-danger">{message}</p>
                <% end %>
              </div>

              <button
                type="submit"
                phx-disable-with="Saving..."
                class="flex items-center gap-2 rounded-xl bg-brand px-5 py-2.5 text-[12.5px] font-semibold text-white shadow-sm shadow-brand/30 transition hover:bg-brand-600 disabled:opacity-60"
              >
                <.icon name="hero-lock-closed" class="size-4" /> Save Password
              </button>
            </.form>
          </div>

          <p class="mt-5 text-center text-[11.5px] text-muted">
            Need to update your profile instead?
            <.link navigate={~p"/users/profile"} class="font-semibold text-brand hover:underline">
              Edit profile
            </.link>
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end
end
