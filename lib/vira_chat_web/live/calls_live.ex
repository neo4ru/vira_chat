defmodule ViraChatWeb.CallsLive do
  use ViraChatWeb, :live_view

  alias ViraChat.Calls
  alias ViraChat.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    {:ok,
     socket
     |> assign(:current_user, user)
     |> assign(:filter, "all")
     |> assign(:selected, nil)
     |> load_calls()}
  end

  defp load_calls(socket) do
    user = socket.assigns.current_user
    filter = socket.assigns.filter

    socket
    |> assign(:calls, Calls.list_calls_for_user(user.id, filter: filter))
    |> assign(:stats, Calls.stats_for_user(user.id))
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket)
      when filter in ["all", "missed", "video"] do
    {:noreply, socket |> assign(:filter, filter) |> assign(:selected, nil) |> load_calls()}
  end

  def handle_event("select", %{"id" => id}, socket) do
    case Calls.get_call(id, socket.assigns.current_user.id) do
      nil -> {:noreply, put_flash(socket, :error, "Call not found")}
      call -> {:noreply, assign(socket, :selected, call)}
    end
  end

  def handle_event("close_selected", _params, socket) do
    {:noreply, assign(socket, :selected, nil)}
  end

  def handle_event("open_conversation", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/chat/#{id}")}
  end

  def handle_event("call_back", _params, socket) do
    case socket.assigns.selected do
      nil ->
        {:noreply, socket}

      call ->
        {:noreply,
         push_navigate(socket, to: ~p"/chat/#{call.conversation_id}?call=#{call.call_type}")}
    end
  end

  # --- Template helpers ---

  defp other_user(call, user) do
    if call.caller_id == user.id, do: call.callee, else: call.caller
  end

  defp direction(call, user) do
    cond do
      call.status in ["missed", "declined"] and call.caller_id != user.id -> :missed
      call.caller_id == user.id -> :outgoing
      true -> :incoming
    end
  end

  defp direction_label(:outgoing), do: "Outgoing"
  defp direction_label(:incoming), do: "Incoming"
  defp direction_label(:missed), do: "Missed"

  defp status_label("completed"), do: "Completed"
  defp status_label("answered"), do: "In progress"
  defp status_label("declined"), do: "Declined"
  defp status_label("missed"), do: "Missed"
  defp status_label(_), do: "Unknown"

  defp call_time(call) do
    if NaiveDateTime.to_date(call.inserted_at) == NaiveDateTime.to_date(NaiveDateTime.utc_now()) do
      Calendar.strftime(call.inserted_at, "%H:%M")
    else
      Calendar.strftime(call.inserted_at, "%d %b, %H:%M")
    end
  end

  defp duration_label(call) do
    case call.duration_seconds do
      nil -> "—"
      0 -> "—"
      seconds -> "#{div(seconds, 60)}:#{String.pad_leading("#{rem(seconds, 60)}", 2, "0")}"
    end
  end

  defp display_name(nil), do: "Unknown"
  defp display_name(user), do: User.display_name(user)
end
