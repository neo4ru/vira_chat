defmodule ViraChat.Notifications do
  import Ecto.Query
  require Logger

  alias ViraChat.Repo
  alias ViraChat.Notifications.PushSubscription
  alias ViraChat.Accounts.User

  @doc """
  True when a VAPID key pair is configured for web push.
  """
  def push_enabled? do
    is_binary(Application.get_env(:web_push_elixir, :vapid_public_key)) and
      is_binary(Application.get_env(:web_push_elixir, :vapid_private_key))
  end

  def save_subscription(user_id, %{
        "endpoint" => endpoint,
        "keys" => %{"p256dh" => p256dh, "auth" => auth}
      }) do
    # Upsert: if the same endpoint exists, reassign it to this user.
    case Repo.get_by(PushSubscription, endpoint: endpoint) do
      nil ->
        %PushSubscription{}
        |> PushSubscription.changeset(%{
          user_id: user_id,
          endpoint: endpoint,
          p256dh: p256dh,
          auth: auth
        })
        |> Repo.insert()

      existing ->
        existing
        |> PushSubscription.changeset(%{
          user_id: user_id,
          p256dh: p256dh,
          auth: auth
        })
        |> Repo.update()
    end
  end

  def save_subscription(_user_id, _subscription), do: {:error, :invalid_subscription}

  def list_subscriptions(user_id) do
    from(s in PushSubscription, where: s.user_id == ^user_id)
    |> Repo.all()
  end

  def delete_subscription(endpoint) do
    from(s in PushSubscription, where: s.endpoint == ^endpoint)
    |> Repo.delete_all()
  end

  @doc """
  Notifies all subscriptions of the given participants, except the sender.

  Runs asynchronously so it never blocks the LiveView, and is a no-op when no
  VAPID key pair is configured.
  """
  def notify_participants(participants, sender, message, conversation) do
    if push_enabled?() do
      sender_name = User.display_name(sender)

      preview =
        cond do
          message.content && message.content != "" -> String.slice(message.content, 0, 80)
          message.media_url -> "📎 Image"
          true -> "New message"
        end

      title =
        case conversation.type do
          "group" -> "#{conversation.title} · #{sender_name}"
          _ -> sender_name
        end

      payload = %{
        title: title,
        body: preview,
        url: "/chat/#{conversation.id}"
      }

      participants
      |> Enum.reject(&(&1.id == sender.id))
      |> Enum.map(& &1.id)
      |> Enum.each(fn recipient_id ->
        Task.start(fn -> send_to_user(recipient_id, payload) end)
      end)
    end

    :ok
  end

  defp send_to_user(user_id, payload) do
    for sub <- list_subscriptions(user_id) do
      subscription = %{
        endpoint: sub.endpoint,
        keys: %{
          p256dh: sub.p256dh,
          auth: sub.auth
        }
      }

      case WebPushElixir.send_notification(subscription, payload) do
        {:ok, _} ->
          :ok

        {:error, :expired} ->
          # Subscription expired — remove it
          delete_subscription(sub.endpoint)

        {:error, reason} ->
          Logger.debug("Push notification failed: #{inspect(reason)}")
      end
    end
  rescue
    error ->
      Logger.warning("Could not send push notification: #{Exception.message(error)}")
  end
end
