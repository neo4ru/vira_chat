defmodule ViraChat.Repo do
  use Ecto.Repo,
    otp_app: :vira_chat,
    adapter: Ecto.Adapters.Postgres
end
