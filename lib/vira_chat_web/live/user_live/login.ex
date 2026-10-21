defmodule ViraChatWeb.UserLive.Login do
  use ViraChatWeb, :live_view
  alias ViraChat.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.auth_shell
        title="Welcome back"
        subtitle={
          if @current_scope,
            do: "Reauthenticate to perform sensitive actions.",
            else: "Log in to continue your conversations."
        }
      >
        <div
          :if={local_mail_adapter?()}
          class="mb-5 flex items-start gap-2 rounded-xl border border-brand/15 bg-brand-soft px-3 py-2.5 text-[11.5px] leading-relaxed text-brand"
        >
          <.icon name="hero-information-circle" class="mt-0.5 size-4 flex-shrink-0" />
          <p>
            Running the local mail adapter — emails appear in
            <a href="/dev/mailbox" class="font-semibold underline">the mailbox</a>.
          </p>
        </div>

        <div class="rounded-2xl border border-line bg-white p-5 shadow-sm dark:border-[#242424] dark:bg-[#141414]">
          <.form
            for={@form}
            id="login_form_magic"
            action={~p"/users/log-in"}
            phx-submit="submit_magic"
            class="space-y-3"
          >
            <div>
              <label
                for={@form[:email].id}
                class="mb-1.5 block text-[12px] font-semibold text-ink dark:text-white"
              >
                Email
              </label>
              <input
                type="email"
                name={@form[:email].name}
                id={@form[:email].id}
                value={@form[:email].value}
                readonly={!!@current_scope}
                required
                autocomplete="username"
                placeholder="you@example.com"
                class="w-full rounded-xl border border-line bg-surface-2 px-3.5 py-2.5 text-[13px] text-ink outline-none transition placeholder:text-muted focus:border-brand/40 focus:bg-white focus:ring-2 focus:ring-brand/15 dark:border-[#2a2a2a] dark:bg-[#161616] dark:text-white dark:focus:bg-[#111]"
              />
            </div>

            <button
              type="submit"
              class="w-full rounded-xl bg-brand px-4 py-2.5 text-[13px] font-semibold text-white shadow-sm shadow-brand/30 transition hover:bg-brand-600"
            >
              Send me a login link
            </button>
          </.form>

          <div class="my-5 flex items-center gap-3">
            <div class="h-px flex-1 bg-line dark:bg-[#2a2a2a]"></div>
            <span class="text-[10px] font-bold uppercase tracking-[0.12em] text-muted">or</span>
            <div class="h-px flex-1 bg-line dark:bg-[#2a2a2a]"></div>
          </div>

          <.form
            for={@form}
            id="login_form_password"
            action={~p"/users/log-in"}
            phx-submit="submit_password"
            phx-trigger-action={@trigger_submit}
            class="space-y-3"
          >
            <div>
              <label
                for="pw_user_email"
                class="mb-1.5 block text-[12px] font-semibold text-ink dark:text-white"
              >
                Email
              </label>
              <input
                type="email"
                name={@form[:email].name}
                id="pw_user_email"
                value={@form[:email].value}
                readonly={!!@current_scope}
                required
                autocomplete="username"
                class="w-full rounded-xl border border-line bg-surface-2 px-3.5 py-2.5 text-[13px] text-ink outline-none transition placeholder:text-muted focus:border-brand/40 focus:bg-white focus:ring-2 focus:ring-brand/15 dark:border-[#2a2a2a] dark:bg-[#161616] dark:text-white dark:focus:bg-[#111]"
              />
            </div>

            <div>
              <div class="mb-1.5 flex items-center justify-between">
                <label for="pw_user_password" class="text-[12px] font-semibold text-ink dark:text-white">
                  Password
                </label>
                <.link
                  navigate={~p"/users/reset-password"}
                  class="text-[11.5px] font-semibold text-brand hover:underline"
                >
                  Forgot password?
                </.link>
              </div>
              <input
                type="password"
                name={@form[:password].name}
                id="pw_user_password"
                required
                autocomplete="current-password"
                placeholder="••••••••"
                class="w-full rounded-xl border border-line bg-surface-2 px-3.5 py-2.5 text-[13px] text-ink outline-none transition placeholder:text-muted focus:border-brand/40 focus:bg-white focus:ring-2 focus:ring-brand/15 dark:border-[#2a2a2a] dark:bg-[#161616] dark:text-white dark:focus:bg-[#111]"
              />
            </div>

            <button
              type="submit"
              name={@form[:remember_me].name}
              value="true"
              class="w-full rounded-xl bg-brand px-4 py-2.5 text-[13px] font-semibold text-white shadow-sm shadow-brand/30 transition hover:bg-brand-600"
            >
              Log in and stay logged in
            </button>
            <button
              type="submit"
              class="w-full rounded-xl border border-line bg-white px-4 py-2.5 text-[13px] font-semibold text-ink transition hover:border-brand/30 hover:text-brand dark:border-[#2a2a2a] dark:bg-[#161616] dark:text-white"
            >
              Log in only this time
            </button>
          </.form>
        </div>

        <p class="mt-5 text-center text-[12.5px] text-body">
          Don't have an account?
          <.link navigate={~p"/users/register"} class="font-semibold text-brand hover:underline">
            Sign up
          </.link>
        </p>
      </.auth_shell>
    </Layouts.app>
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
