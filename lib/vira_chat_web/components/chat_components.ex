defmodule ViraChatWeb.ChatComponents do
  @moduledoc """
  UI components specific to the chat interface.
  """
  use Phoenix.Component

  @doc """
  Renders the emoji picker dropdown.
  Requires the `EmojiPicker` JS hook and `emoji-picker-element` imported in app.js.
  """
  def emoji_picker(assigns) do
    ~H"""
    <div id="emoji-picker-wrapper" phx-hook="EmojiPicker" phx-update="ignore" class="relative">
      <!-- Trigger Button -->
      <button type="button" data-emoji-toggle class="w-10 h-10 flex items-center justify-center rounded-full text-slate-500 dark:text-slate-400 hover:text-indigo-600 dark:hover:text-indigo-400 hover:bg-slate-100 dark:hover:bg-slate-800 transition text-xl">😊</button>

      <!-- Emoji Panel (Uses Web Component) -->
      <div data-emoji-panel class="hidden absolute bottom-14 left-0 z-20 shadow-2xl rounded-2xl overflow-hidden border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800">
        <emoji-picker class="light dark:dark" style="height: 350px; width: 320px; --background: transparent; --border-color: transparent;"></emoji-picker>
      </div>
    </div>
    """
  end
end
