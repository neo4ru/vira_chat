defmodule ViraChat.Chat.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "conversations" do
    field :type, :string
    field :title, :string
    field :avatar_url, :string

    many_to_many :users, ViraChat.Accounts.User,
      join_through: "participants",
      join_keys: [conversation_id: :id, user_id: :id]

    has_many :messages, ViraChat.Chat.Message

    timestamps()
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:type, :title, :avatar_url])
    |> validate_required([:type])
  end

  @group_gradients [
    "from-violet-500 to-purple-600",
    "from-fuchsia-500 to-pink-600",
    "from-rose-500 to-red-600",
    "from-amber-500 to-orange-600",
    "from-emerald-500 to-teal-600",
    "from-cyan-500 to-blue-600",
    "from-indigo-500 to-violet-600"
  ]

  def group_gradient(%__MODULE__{id: id}) when is_integer(id) do
    idx = rem(id, length(@group_gradients))
    Enum.at(@group_gradients, idx)
  end

  def group_gradient(_), do: "from-violet-500 to-purple-600"
end
