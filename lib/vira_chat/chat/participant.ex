defmodule ViraChat.Chat.Participant do
  use Ecto.Schema
  import Ecto.Changeset

  schema "participants" do
    field :last_read_at, :utc_datetime
    field :delivered_at, :utc_datetime
    field :muted_at, :utc_datetime
    field :pinned_at, :utc_datetime
    field :archived_at, :utc_datetime

    belongs_to :user, ViraChat.Accounts.User
    belongs_to :conversation, ViraChat.Chat.Conversation

    timestamps()
  end

  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [
      :user_id,
      :conversation_id,
      :last_read_at,
      :delivered_at,
      :muted_at,
      :pinned_at,
      :archived_at
    ])
    |> validate_required([:user_id, :conversation_id])
    |> unique_constraint([:user_id, :conversation_id])
  end
end
