defmodule ViraChat.Chat.MessageReaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "message_reactions" do
    field :emoji, :string

    belongs_to :message, ViraChat.Chat.Message
    belongs_to :user, ViraChat.Accounts.User

    timestamps()
  end

  def changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:message_id, :user_id, :emoji])
    |> validate_required([:message_id, :user_id, :emoji])
    |> validate_length(:emoji, max: 8)
    |> unique_constraint([:message_id, :user_id, :emoji])
  end
end
