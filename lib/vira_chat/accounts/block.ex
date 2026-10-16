defmodule ViraChat.Accounts.Block do
  use Ecto.Schema
  import Ecto.Changeset

  schema "blocks" do
    belongs_to :blocker, ViraChat.Accounts.User, foreign_key: :blocker_id
    belongs_to :blocked, ViraChat.Accounts.User, foreign_key: :blocked_id

    timestamps()
  end

  def changeset(block, attrs) do
    block
    |> cast(attrs, [:blocker_id, :blocked_id])
    |> validate_required([:blocker_id, :blocked_id])
    |> foreign_key_constraint(:blocker_id)
    |> foreign_key_constraint(:blocked_id)
    |> unique_constraint([:blocker_id, :blocked_id])
    |> validate_not_self()
  end

  defp validate_not_self(changeset) do
    blocker = get_field(changeset, :blocker_id)
    blocked = get_field(changeset, :blocked_id)

    if blocker && blocked && blocker == blocked do
      add_error(changeset, :blocked_id, "cannot block yourself")
    else
      changeset
    end
  end
end
