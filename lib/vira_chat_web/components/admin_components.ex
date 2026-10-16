defmodule ViraChatWeb.AdminComponents do
  use Phoenix.Component

  attr :active, :atom, required: true
  attr :current_user, :map, required: true
  slot :inner_block, required: true

  def admin_layout(assigns) do
    ~H"""
    <div class="flex h-screen bg-gray-100">
      <aside class="w-64 bg-gray-900 text-white flex flex-col flex-shrink-0">
        <div class="p-4 border-b border-gray-800">
          <h1 class="text-lg font-bold">ViraChat Admin</h1>
          <p class="text-xs text-gray-400 mt-1 truncate">
            <%= @current_user.email %>
          </p>
          <p class="text-xs text-blue-400 mt-0.5 uppercase tracking-wide">
            <%= ViraChat.Accounts.User.role_label(@current_user) %>
          </p>
        </div>

        <nav class="flex-1 p-2 space-y-1">
  <.nav_link to="/admin" active={@active == :dashboard}>📊 Dashboard</.nav_link>
  <.nav_link to="/admin/users" active={@active == :users}>👥 Users</.nav_link>
  <.nav_link to="/admin/conversations" active={@active == :conversations}>💬 Conversations</.nav_link>
  <.nav_link to="/admin/audit" active={@active == :audit}>📜 Audit log</.nav_link>
  <.nav_link to="/admin/reports" active={@active == :reports}>🚩 Reports</.nav_link>
</nav>

        <div class="p-2 border-t border-gray-800 space-y-1">
          <.link
            navigate="/chat"
            class="block px-3 py-2 text-sm text-gray-300 hover:bg-gray-800 rounded"
          >
            ← Back to chat
          </.link>
          <.link
            href="/users/log-out"
            method="delete"
            class="block px-3 py-2 text-sm text-red-400 hover:bg-gray-800 rounded"
          >
            Log out
          </.link>
        </div>
      </aside>

      <main class="flex-1 overflow-y-auto p-6">
        <%= render_slot(@inner_block) %>
      </main>
    </div>
    """
  end

  attr :to, :string, required: true
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  defp nav_link(assigns) do
    ~H"""
    <.link
      navigate={@to}
      class={"block px-3 py-2 rounded text-sm #{if @active, do: "bg-blue-600 text-white", else: "text-gray-300 hover:bg-gray-800"}"}
    >
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :color, :string, default: "blue"

  def stat_card(assigns) do
    color_class =
      case assigns.color do
        "green" -> "bg-green-50 text-green-700"
        "red" -> "bg-red-50 text-red-700"
        "purple" -> "bg-purple-50 text-purple-700"
        "indigo" -> "bg-indigo-50 text-indigo-700"
        "amber" -> "bg-amber-50 text-amber-700"
        _ -> "bg-blue-50 text-blue-700"
      end

    assigns = assign(assigns, :color_class, color_class)

    ~H"""
    <div class={"rounded-lg p-4 #{@color_class}"}>
      <div class="text-xs uppercase tracking-wide opacity-80"><%= @label %></div>
      <div class="text-2xl font-bold mt-1"><%= @value %></div>
    </div>
    """
  end

  # --- Audit log helpers ---

  def action_badge_class("ban_user"), do: "bg-yellow-100 text-yellow-800"
  def action_badge_class("unban_user"), do: "bg-green-100 text-green-800"
  def action_badge_class("change_role"), do: "bg-blue-100 text-blue-800"
  def action_badge_class("delete_user"), do: "bg-red-100 text-red-800"
  def action_badge_class("delete_conversation"), do: "bg-red-100 text-red-800"
  def action_badge_class(_), do: "bg-gray-100 text-gray-800"

  def format_details(nil), do: "—"
  def format_details(map) when map == %{}, do: "—"

  def format_details(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> "#{k}: #{inspect(v)}" end)
    |> Enum.join(" · ")
  end
end
