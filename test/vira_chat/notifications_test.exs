defmodule ViraChat.NotificationsTest do
  use ExUnit.Case, async: true

  alias ViraChat.Notifications

  test "push is disabled without a VAPID key pair" do
    refute Notifications.push_enabled?()
    assert :ok = Notifications.notify_participants([], nil, nil, nil)
  end

  test "invalid subscriptions are rejected" do
    assert {:error, :invalid_subscription} = Notifications.save_subscription(1, %{})
  end
end
