defmodule ViraChatWeb.UserLive.Registration do
  use ViraChatWeb, :live_view
  alias ViraChat.Accounts
  alias ViraChat.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.auth_shell
        title="Create your account"
        subtitle="Enter your email — we'll send you a secure link to get started."
      >
        <div class="rounded-2xl border border-line bg-white p-5 shadow-sm dark:border-[#242424] dark:bg-[#141414]">
          <.form
            for={@form}
            id="registration_form"
            phx-submit="save"
            phx-change="validate"
            class="space-y-4"
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
                required
                autofocus
                autocomplete="username"
                spellcheck="false"
                phx-mounted={JS.focus()}
                placeholder="you@example.com"
                class="w-full rounded-xl border border-line bg-surface-2 px-3.5 py-2.5 text-[13px] text-ink outline-none transition placeholder:text-muted focus:border-brand/40 focus:bg-white focus:ring-2 focus:ring-brand/15 dark:border-[#2a2a2a] dark:bg-[#161616] dark:text-white dark:focus:bg-[#111]"
              />
              <%= for {message, _opts} <- @form[:email].errors do %>
                <p class="mt-1 text-[11px] font-medium text-danger">{message}</p>
              <% end %>
            </div>

            <button
              type="submit"
              phx-disable-with="Creating account..."
              class="w-full rounded-xl bg-brand px-4 py-2.5 text-[13px] font-semibold text-white shadow-sm shadow-brand/30 transition hover:bg-brand-600 disabled:opacity-60"
            >
              Create an account
            </button>
          </.form>

          <p class="mt-4 text-center text-[11px] leading-relaxed text-muted">
            By creating an account you agree to our Terms and Privacy Policy.
          </p>
        </div>

        <p class="mt-5 text-center text-[12.5px] text-body">
          Already have an account?
          <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
            Log in
          </.link>
        </p>
      </.auth_shell>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: ~p"/chat")}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_email(%User{}, %{}, validate_unique: false)

    {:ok, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} = Accounts.deliver_login_instructions(user, &url(~p"/users/log-in/#{&1}"))

        {:noreply,
         socket
         |> put_flash(
           :info,
           "An email was sent to #{user.email}, please access it to confirm your account."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_email(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
