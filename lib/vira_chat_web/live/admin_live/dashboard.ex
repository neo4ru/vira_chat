defmodule ViraChatWeb.AdminLive.Dashboard do
  use ViraChatWeb, :live_view
  import ViraChatWeb.AdminComponents
  alias ViraChat.Admin

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(10_000, self(), :refresh)
    end

    {:ok,
     socket
     |> assign(:current_user, socket.assigns.current_scope.user)
     |> assign(:stats, Admin.stats())
     |> assign(:recent_messages, Admin.recent_messages(15))}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply,
     socket
     |> assign(:stats, Admin.stats())
     |> assign(:recent_messages, Admin.recent_messages(15))}
  end
end
