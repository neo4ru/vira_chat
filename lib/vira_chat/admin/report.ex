defmodule ViraChat.Admin.Report do
  use Ecto.Schema
  import Ecto.Changeset

  schema "reports" do
    field :reason, :string
    field :details, :string
    field :status, :string, default: "pending"
    field :resolved_at, :utc_datetime

    belongs_to :reporter, ViraChat.Accounts.User
    belongs_to :reported_user, ViraChat.Accounts.User
    belongs_to :message, ViraChat.Chat.Message
    belongs_to :conversation, ViraChat.Chat.Conversation
    belongs_to :resolved_by, ViraChat.Accounts.User

    timestamps()
  end

  @reasons ~w(spam harassment inappropriate scam other)

  def changeset(report, attrs) do
    report
    |> cast(attrs, [:reporter_id, :reported_user_id, :message_id, :conversation_id, :reason, :details])
    |> validate_required([:reporter_id, :reason])
    |> validate_inclusion(:reason, @reasons)
    |> validate_length(:details, max: 500)
  end

  def resolve_changeset(report, resolver_id, status) when status in ["resolved", "dismissed"] do
    report
    |> change(
      status: status,
      resolved_at: DateTime.utc_now() |> DateTime.truncate(:second),
      resolved_by_id: resolver_id
    )
  end

  def reasons, do: @reasons

  def reason_label("spam"), do: "Spam"
  def reason_label("harassment"), do: "Harassment"
  def reason_label("inappropriate"), do: "Inappropriate content"
  def reason_label("scam"), do: "Scam / fraud"
  def reason_label("other"), do: "Other"
  def reason_label(x), do: x

  def status_label("pending"), do: "Pending"
  def status_label("resolved"), do: "Resolved"
  def status_label("dismissed"), do: "Dismissed"
  def status_label(x), do: x
end
