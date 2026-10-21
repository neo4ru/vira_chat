defmodule ViraChatWeb.ChatComponents do
  @moduledoc """
  UI components specific to the chat interface.
  """
  use ViraChatWeb, :html

  @doc """
  Renders the emoji picker dropdown.
  Requires the `EmojiPicker` JS hook and `emoji-picker-element` imported in app.js.
  """
  def emoji_picker(assigns) do
    ~H"""
    <div
      id="emoji-picker-wrapper"
      phx-hook="EmojiPicker"
      phx-update="ignore"
      class="relative flex items-center"
    >
      <button
        type="button"
        data-emoji-toggle
        aria-label="Emoji picker"
        title="Emoji"
        class="flex h-11 w-11 items-center justify-center rounded-full text-body transition hover:bg-surface-2 hover:text-brand dark:hover:bg-[#161616]"
      >
        <.icon name="hero-face-smile" class="size-5" />
      </button>

      <div
        data-emoji-panel
        class="absolute bottom-14 left-0 z-30 hidden overflow-hidden rounded-2xl border border-line bg-white shadow-pop dark:border-[#2a2a2a] dark:bg-[#141414]"
      >
        <emoji-picker
          class="light dark:dark"
          style="height: 340px; width: 300px; --background: transparent; --border-color: transparent;"
        >
        </emoji-picker>
      </div>
    </div>
    """
  end
end
