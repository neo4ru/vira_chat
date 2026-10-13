defmodule ViraChatWeb.AdminLive.Audit do
  use ViraChatWeb, :live_view
  import ViraChatWeb.AdminComponents
  alias ViraChat.Admin

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_user, socket.assigns.current_scope.user)
     |> assign(:action_filter, "")
     |> assign(:actions, Admin.distinct_actions())
     |> assign(:entries, Admin.list_audit_actions())}
  end

  @impl true
  def handle_event("filter", %{"action" => action}, socket) do
    entries = Admin.list_audit_actions(action: action)
    {:noreply, socket |> assign(:action_filter, action) |> assign(:entries, entries)}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply,
     socket
     |> assign(:actions, Admin.distinct_actions())
     |> assign(:entries, Admin.list_audit_actions(action: socket.assigns.action_filter))}
  end
end
