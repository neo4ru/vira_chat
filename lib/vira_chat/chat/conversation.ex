defmodule ViraChat.Chat.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "conversations" do
    field :type, :string
    field :title, :string

    many_to_many :users, ViraChat.Accounts.User,
      join_through: "participants",
      join_keys: [conversation_id: :id, user_id: :id]

    has_many :messages, ViraChat.Chat.Message

    timestamps()
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:type, :title])
    |> validate_required([:type])
  end
end
