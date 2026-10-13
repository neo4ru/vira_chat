defmodule ViraChatWeb.UserLive.Registration do
  use ViraChatWeb, :live_view
  alias ViraChat.Accounts
  alias ViraChat.Accounts.User

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
          <h1 class="text-2xl font-bold text-gray-900 mt-6">Create your account</h1>
          <p class="text-gray-500 text-sm mt-1">
            Enter your email — we'll send you a link to get started
          </p>
        </div>

        <div class="bg-white rounded-2xl shadow-xl shadow-slate-900/5 border border-gray-100 p-8">
          <.form
            :let={f}
            for={@form}
            id="registration_form"
            phx-submit="save"
            phx-change="validate"
            class="space-y-4"
          >
            <div>
              <label for={f[:email].id} class="block text-sm font-medium text-gray-700 mb-1">Email</label>
              <input
                type="email"
                name={f[:email].name}
                id={f[:email].id}
                value={f[:email].value}
                required
                autofocus
                autocomplete="username"
                spellcheck="false"
                phx-mounted={JS.focus()}
                class="w-full px-4 py-2.5 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="you@example.com"
              />
              <p :if={f[:email].errors != []} class="mt-1 text-xs text-red-600">
                <%= f[:email].errors |> Enum.map(&elem(&1, 0)) |> Enum.join(", ") %>
              </p>
            </div>

            <button
              type="submit"
              phx-disable-with="Creating account..."
              class="w-full py-2.5 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-semibold transition"
            >
              Create an account
            </button>
          </.form>

          <p class="text-xs text-gray-500 text-center mt-4">
            By creating an account you agree to our Terms and Privacy Policy.
          </p>
        </div>

        <p class="text-center text-sm text-gray-500 mt-6">
          Already have an account?
          <.link navigate={~p"/users/log-in"} class="text-blue-600 hover:underline font-medium">
            Log in
          </.link>
        </p>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: ViraChatWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_email(%User{}, %{}, validate_unique: false)

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
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
