defmodule ViraChatWeb.UserLive.Login do
  use ViraChatWeb, :live_view
  alias ViraChat.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-50 via-white to-blue-50 px-4 py-12">
      <div class="w-full max-w-md">
        <div class="text-center mb-8">
          <.link navigate={~p"/"} class="inline-flex items-center gap-2">
            <div class="w-11 h-11 rounded-xl bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center text-white font-bold text-xl">V</div>
            <span class="text-2xl font-bold text-gray-900">ViraChat</span>
          </.link>
          <h1 class="text-2xl font-bold text-gray-900 mt-6">Welcome back</h1>
          <p class="text-gray-500 text-sm mt-1">
            <%= if @current_scope do %>
              Reauthenticate to perform sensitive actions
            <% else %>
              Log in to continue your conversations
            <% end %>
          </p>
        </div>

        <div :if={local_mail_adapter?()} class="mb-4 rounded-lg bg-blue-50 border border-blue-200 p-3 text-xs text-blue-800 flex gap-2 items-start">
          <span class="text-base leading-none mt-0.5">ℹ</span>
          <div>
            <p class="font-medium">Running the local mail adapter.</p>
            <p>Sent emails appear in <a href="/dev/mailbox" class="underline">the mailbox</a>.</p>
          </div>
        </div>

        <div class="bg-white rounded-2xl shadow-xl shadow-slate-900/5 border border-gray-100 p-8">
          <.form
            :let={f}
            for={@form}
            id="login_form_magic"
            action={~p"/users/log-in"}
            phx-submit="submit_magic"
            class="space-y-3"
          >
            <div>
              <label for={f[:email].id} class="block text-sm font-medium text-gray-700 mb-1">Email</label>
              <input
                type="email"
                name={f[:email].name}
                id={f[:email].id}
                value={f[:email].value}
                readonly={!!@current_scope}
                required
                autocomplete="username"
                class="w-full px-4 py-2.5 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="you@example.com"
              />
            </div>
            <button
              type="submit"
              class="w-full py-2.5 bg-gray-900 text-white rounded-lg hover:bg-gray-800 font-semibold transition"
            >
              Send me a login link
            </button>
          </.form>

          <div class="flex items-center gap-3 my-6">
            <div class="flex-1 h-px bg-gray-200"></div>
            <span class="text-xs text-gray-400 font-medium">OR</span>
            <div class="flex-1 h-px bg-gray-200"></div>
          </div>

          <.form
            :let={f}
            for={@form}
            id="login_form_password"
            action={~p"/users/log-in"}
            phx-submit="submit_password"
            phx-trigger-action={@trigger_submit}
            class="space-y-3"
          >
            <div>
              <label for={"pw_" <> f[:email].id} class="block text-sm font-medium text-gray-700 mb-1">Email</label>
              <input
                type="email"
                name={f[:email].name}
                id={"pw_" <> f[:email].id}
                value={f[:email].value}
                readonly={!!@current_scope}
                required
                autocomplete="username"
                class="w-full px-4 py-2.5 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>
            <div>
              <div class="flex justify-between items-center mb-1">
                <label for={"pw_" <> f[:password].id} class="block text-sm font-medium text-gray-700">Password</label>
                <.link navigate={~p"/users/reset-password"} class="text-xs text-blue-600 hover:underline">
                  Forgot?
                </.link>
              </div>
              <input
                type="password"
                name={f[:password].name}
                id={"pw_" <> f[:password].id}
                required
                autocomplete="current-password"
                class="w-full px-4 py-2.5 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="••••••••"
              />
            </div>
            <button
              type="submit"
              name={f[:remember_me].name}
              value="true"
              class="w-full py-2.5 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-semibold transition"
            >
              Log in and stay logged in
            </button>
            <button
              type="submit"
              class="w-full py-2.5 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 font-medium transition"
            >
              Log in only this time
            </button>
          </.form>
        </div>

        <p class="text-center text-sm text-gray-500 mt-6">
          Don't have an account?
          <.link navigate={~p"/users/register"} class="text-blue-600 hover:underline font-medium">
            Sign up
          </.link>
        </p>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(user, &url(~p"/users/log-in/#{&1}"))
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:vira_chat, ViraChat.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
