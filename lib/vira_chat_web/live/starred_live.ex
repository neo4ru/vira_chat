defmodule ViraChatWeb.StarredLive do
  use ViraChatWeb, :live_view
  alias ViraChat.Chat
  alias ViraChat.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    messages = Chat.list_starred_messages(user.id)

    {:ok,
     socket
     |> assign(:current_user, user)
     |> assign(:messages, messages)}
  end

  @impl true
  def handle_event("unstar", %{"id" => id}, socket) do
    message_id = String.to_integer(id)
    user = socket.assigns.current_user

    Chat.unstar_message(message_id, user.id)
    messages = Chat.list_starred_messages(user.id)

    {:noreply,
     socket
     |> assign(:messages, messages)
     |> put_flash(:info, "Message unstarred")}
  end

  @impl true
  def handle_event("open_conversation", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/chat/#{id}")}
  end

  # --- Helpers ---

  defp conversation_title(conversation, current_user) do
    case conversation.type do
      "group" -> conversation.title || "Group Chat"
      "private" ->
        other = Enum.find(conversation.users || [], fn u -> u.id != current_user.id end)
        (other && User.display_name(other)) || "Chat"
    end
  end

  defp time_ago(dt) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    dt_as_dt =
      case dt do
        %DateTime{} = d -> d
        %NaiveDateTime{} = nd -> DateTime.from_naive!(nd, "Etc/UTC")
      end

    diff = DateTime.diff(now, dt_as_dt, :second)

    cond do
      diff < 10 -> "just now"
      diff < 60 -> "#{diff}s ago"
      diff < 3_600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3_600)}h ago"
      diff < 604_800 -> "#{div(diff, 86_400)}d ago"
      true -> Calendar.strftime(dt_as_dt, "%b %d, %Y")
    end
  end
end
