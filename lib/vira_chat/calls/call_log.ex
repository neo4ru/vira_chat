defmodule ViraChat.Calls.CallLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "call_logs" do
    field :call_type, :string, default: "voice"
    field :status, :string, default: "missed"
    field :duration_seconds, :integer, default: 0
    field :started_at, :utc_datetime
    field :answered_at, :utc_datetime

    belongs_to :conversation, ViraChat.Chat.Conversation
    belongs_to :caller, ViraChat.Accounts.User
    belongs_to :callee, ViraChat.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(call_log, attrs) do
    call_log
    |> cast(attrs, [
      :conversation_id,
      :caller_id,
      :callee_id,
      :call_type,
      :status,
      :duration_seconds,
      :started_at,
      :answered_at
    ])
    |> validate_required([:conversation_id, :caller_id, :callee_id, :call_type, :status])
    |> validate_inclusion(:call_type, ["voice", "video"])
    |> validate_inclusion(:status, ["missed", "declined", "answered", "completed"])
  end
end
