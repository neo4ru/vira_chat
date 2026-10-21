defmodule ViraChatWeb.AdminComponents do
  use ViraChatWeb, :html

  attr :active, :atom, required: true
  attr :current_user, :map, required: true
  slot :inner_block, required: true

  def admin_layout(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-surface dark:bg-[#0b0b0d]">
      <aside class="hidden w-[240px] flex-shrink-0 flex-col border-r border-line bg-white dark:border-[#222224] dark:bg-[#0d0d0d] lg:flex">
        <div class="flex items-center gap-2.5 border-b border-line px-5 py-5 dark:border-[#222224]">
          <div class="flex h-9 w-9 items-center justify-center rounded-xl bg-brand text-sm font-extrabold text-white">
            V
          </div>
          <div>
            <p class="text-[14px] font-bold leading-tight text-ink dark:text-white">ViraChat</p>
            <p class="text-[10px] font-bold uppercase tracking-[0.1em] text-brand">Admin</p>
          </div>
        </div>

        <div class="border-b border-line px-5 py-4 dark:border-[#222224]">
          <p class="truncate text-[12.5px] font-semibold text-ink dark:text-white">
            {@current_user.email}
          </p>
          <p class="mt-0.5 text-[10px] font-bold uppercase tracking-[0.08em] text-muted">
            {ViraChat.Accounts.User.role_label(@current_user)}
          </p>
        </div>

        <nav class="flex flex-1 flex-col gap-1 p-3">
          <.nav_link to="/admin" active={@active == :dashboard} icon="hero-squares-2x2">
            Dashboard
          </.nav_link>
          <.nav_link to="/admin/users" active={@active == :users} icon="hero-users">
            Users
          </.nav_link>
          <.nav_link
            to="/admin/conversations"
            active={@active == :conversations}
            icon="hero-chat-bubble-left-right"
          >
            Conversations
          </.nav_link>
          <.nav_link to="/admin/reports" active={@active == :reports} icon="hero-flag">
            Reports
          </.nav_link>
          <.nav_link to="/admin/audit" active={@active == :audit} icon="hero-clipboard-document-list">
            Audit log
          </.nav_link>
        </nav>

        <div class="space-y-1 border-t border-line p-3 dark:border-[#222224]">
          <.link
            navigate={~p"/chat"}
            class="flex items-center gap-2 rounded-xl px-3 py-2.5 text-[12.5px] font-medium text-body transition hover:bg-surface-2 hover:text-ink dark:hover:bg-[#161616] dark:hover:text-white"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Back to chats
          </.link>
          <.link
            href={~p"/users/log-out"}
            method="delete"
            class="flex items-center gap-2 rounded-xl px-3 py-2.5 text-[12.5px] font-medium text-body transition hover:bg-danger/10 hover:text-danger"
          >
            <.icon name="hero-arrow-right-on-rectangle" class="size-4" /> Log out
          </.link>
        </div>
      </aside>

      <main class="min-w-0 flex-1">
        <div class="no-scrollbar flex items-center gap-1 overflow-x-auto border-b border-line bg-white px-3 py-2 dark:border-[#222224] dark:bg-[#0d0d0d] lg:hidden">
          <span class="mr-1 flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-lg bg-brand text-xs font-extrabold text-white">
            V
          </span>
          <.nav_link to="/admin" active={@active == :dashboard} icon="hero-squares-2x2" compact>
            Dashboard
          </.nav_link>
          <.nav_link to="/admin/users" active={@active == :users} icon="hero-users" compact>
            Users
          </.nav_link>
          <.nav_link
            to="/admin/conversations"
            active={@active == :conversations}
            icon="hero-chat-bubble-left-right"
            compact
          >
            Chats
          </.nav_link>
          <.nav_link to="/admin/reports" active={@active == :reports} icon="hero-flag" compact>
            Reports
          </.nav_link>
          <.nav_link
            to="/admin/audit"
            active={@active == :audit}
            icon="hero-clipboard-document-list"
            compact
          >
            Audit
          </.nav_link>
        </div>

        <div class="mx-auto max-w-6xl px-4 py-6 sm:px-8">
          {render_slot(@inner_block)}
        </div>
      </main>
    </div>
    """
  end

  attr :to, :string, required: true
  attr :active, :boolean, default: false
  attr :icon, :string, required: true
  attr :compact, :boolean, default: false
  slot :inner_block, required: true

  defp nav_link(assigns) do
    ~H"""
    <.link
      navigate={@to}
      class={[
        "flex items-center gap-2.5 whitespace-nowrap rounded-xl font-medium transition",
        @compact && "px-2.5 py-1.5 text-[12px]",
        !@compact && "px-3 py-2.5 text-[12.5px]",
        @active && "bg-brand text-white shadow-sm shadow-brand/30",
        !@active &&
          "text-body hover:bg-surface-2 hover:text-ink dark:hover:bg-[#161616] dark:hover:text-white"
      ]}
    >
      <.icon name={@icon} class="size-4" />
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :color, :string, default: "blue"

  def stat_card(assigns) do
    dot =
      case assigns.color do
        "green" -> "bg-success"
        "red" -> "bg-danger"
        "purple" -> "bg-[#8b5cf6]"
        "indigo" -> "bg-brand"
        "amber" -> "bg-warning"
        _ -> "bg-brand"
      end

    assigns = assign(assigns, :dot, dot)

    ~H"""
    <div class="rounded-2xl border border-line bg-white p-4 dark:border-[#242424] dark:bg-[#141414]">
      <div class="flex items-center justify-between gap-2">
        <p class="text-[10px] font-bold uppercase tracking-[0.08em] text-muted">{@label}</p>
        <span class={"h-2 w-2 flex-shrink-0 rounded-full #{@dot}"}></span>
      </div>
      <p class="mt-2 text-[24px] font-bold leading-none text-ink dark:text-white">{@value}</p>
    </div>
    """
  end

  # --- Audit log helpers ---

  def action_badge_class("ban_user"), do: "bg-warning/10 text-warning"
  def action_badge_class("unban_user"), do: "bg-success/10 text-success"
  def action_badge_class("change_role"), do: "bg-brand-soft text-brand"
  def action_badge_class("delete_user"), do: "bg-danger/10 text-danger"
  def action_badge_class("delete_conversation"), do: "bg-danger/10 text-danger"
  def action_badge_class(_), do: "bg-surface-2 text-body dark:bg-[#242424] dark:text-[#d8dfeb]"

  def format_details(nil), do: "—"
  def format_details(map) when map == %{}, do: "—"

  def format_details(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> "#{k}: #{inspect(v)}" end)
    |> Enum.join(" · ")
  end
end
