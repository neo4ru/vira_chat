defmodule ViraChatWeb.AdminLive.Conversations do
  use ViraChatWeb, :live_view
  import ViraChatWeb.AdminComponents
  alias ViraChat.Admin

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_user, socket.assigns.current_scope.user)
     |> assign(:conversations, Admin.list_conversations())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    conversation = Admin.get_conversation!(id)
    actor = socket.assigns.current_user

    Admin.delete_conversation(conversation, actor)

    {:noreply,
     socket
     |> assign(:conversations, Admin.list_conversations())
     |> put_flash(:info, "Conversation deleted")}
  end
end
