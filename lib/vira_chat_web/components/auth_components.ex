defmodule ViraChatWeb.AuthComponents do
  @moduledoc """
  Shared shell for the authentication screens (login, registration, reset).
  """
  use Phoenix.Component

  import ViraChatWeb.CoreComponents, only: [icon: 1]

  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  slot :inner_block, required: true

  def auth_shell(assigns) do
    ~H"""
    <div class="min-h-screen bg-white dark:bg-[#0b0b0d] lg:grid lg:grid-cols-[1.05fr_1fr]">
      <aside class="relative hidden overflow-hidden bg-gradient-to-br from-brand via-[#7c3aed] to-[#a855f7] px-12 py-10 text-white lg:flex lg:flex-col">
        <div class="pointer-events-none absolute -right-24 -top-24 h-80 w-80 rounded-full bg-white/10 blur-2xl">
        </div>
        <div class="pointer-events-none absolute -bottom-24 -left-20 h-80 w-80 rounded-full bg-white/10 blur-2xl">
        </div>

        <a href="/" class="relative flex items-center gap-2.5">
          <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-white/15 text-lg font-extrabold backdrop-blur">
            V
          </span>
          <span class="text-[19px] font-bold tracking-tight">ViraChat</span>
        </a>

        <div class="relative mt-auto max-w-sm">
          <h2 class="text-[34px] font-extrabold leading-[1.1] tracking-tight">
            Conversations that feel effortless.
          </h2>
          <p class="mt-3 text-[14px] leading-relaxed text-white/80">
            Real-time messages, groups, presence, calls and file sharing — in one calm place.
          </p>

          <div class="mt-8 space-y-3">
            <%= for {icon, text} <- [
              {"hero-bolt", "Messages arrive instantly, everywhere"},
              {"hero-user-group", "Group chats with roles and shared media"},
              {"hero-shield-check", "Private by default — no ads, no tracking"}
            ] do %>
              <div class="flex items-center gap-3 text-[13px] font-medium text-white/90">
                <span class="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-lg bg-white/15">
                  <.icon name={icon} class="size-4" />
                </span>
                {text}
              </div>
            <% end %>
          </div>
        </div>

        <p class="relative mt-10 text-[11.5px] text-white/60">
          © {DateTime.utc_now().year} ViraChat. Built with Elixir &amp; Phoenix.
        </p>
      </aside>

      <main class="flex min-h-screen items-center justify-center px-4 py-10 sm:px-6">
        <div class="w-full max-w-[420px]">
          <div class="mb-8 flex items-center gap-2.5 lg:hidden">
            <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-brand text-lg font-extrabold text-white shadow-sm shadow-brand/30">
              V
            </span>
            <span class="text-[19px] font-bold tracking-tight text-ink dark:text-white">ViraChat</span>
          </div>

          <h1 class="text-[26px] font-extrabold tracking-tight text-ink dark:text-white">
            {@title}
          </h1>
          <p class="mt-1.5 text-[13px] leading-relaxed text-body">{@subtitle}</p>

          <div class="mt-6">
            {render_slot(@inner_block)}
          </div>
        </div>
      </main>
    </div>
    """
  end
end
