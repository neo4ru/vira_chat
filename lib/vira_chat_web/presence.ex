defmodule ViraChatWeb.Presence do
  use Phoenix.Presence,
    otp_app: :vira_chat,
    pubsub_server: ViraChat.PubSub
end
