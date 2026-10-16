defmodule ViraChat.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :content, :string
    field :media_url, :string
    field :edited_at, :utc_datetime
    field :deleted_at, :utc_datetime
    field :link_preview, :map

    belongs_to :user, ViraChat.Accounts.User
    belongs_to :conversation, ViraChat.Chat.Conversation
    belongs_to :reply_to, __MODULE__, foreign_key: :reply_to_id
    belongs_to :forwarded_from, __MODULE__, foreign_key: :forwarded_from_id
    has_many :reactions, ViraChat.Chat.MessageReaction, on_delete: :delete_all
    has_many :stars, ViraChat.Chat.MessageStar, on_delete: :delete_all
    timestamps()
  end

def changeset(message, attrs) do
  message
  |> cast(attrs, [:content, :user_id, :conversation_id, :media_url, :reply_to_id, :forwarded_from_id, :link_preview])
  |> validate_required([:user_id, :conversation_id])
end

  def edit_changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :edited_at])
    |> validate_required([:content])
  end

  def delete_changeset(message, attrs) do
    message
    |> cast(attrs, [:deleted_at])
  end

  def deleted?(%__MODULE__{deleted_at: nil}), do: false
  def deleted?(%__MODULE__{}), do: true

  def edited?(%__MODULE__{edited_at: nil}), do: false
  def edited?(%__MODULE__{deleted_at: nil}), do: true
  def edited?(%__MODULE__{}), do: false
end
