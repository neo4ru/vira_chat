defmodule ViraChat.Chat.MessageStar do
  use Ecto.Schema
  import Ecto.Changeset

  schema "message_stars" do
    belongs_to :message, ViraChat.Chat.Message
    belongs_to :user, ViraChat.Accounts.User

    timestamps(updated_at: false)
  end

  def changeset(star, attrs) do
    star
    |> cast(attrs, [:message_id, :user_id])
    |> validate_required([:message_id, :user_id])
    |> unique_constraint([:message_id, :user_id])
  end
end
