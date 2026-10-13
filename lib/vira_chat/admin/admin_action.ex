defmodule ViraChat.Admin.AdminAction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "admin_actions" do
    field :action, :string
    field :details, :map, default: %{}

    belongs_to :actor, ViraChat.Accounts.User, foreign_key: :actor_id
    belongs_to :target_user, ViraChat.Accounts.User, foreign_key: :target_user_id

    # Only inserted_at, no updated_at
    timestamps(updated_at: false)
  end

  def changeset(action, attrs) do
    action
    |> cast(attrs, [:actor_id, :target_user_id, :action, :details])
    |> validate_required([:actor_id, :action])
  end

  @doc """
  Human-readable label for each action type.
  """
  def label("ban_user"), do: "Banned user"
  def label("unban_user"), do: "Unbanned user"
  def label("change_role"), do: "Changed role"
  def label("delete_user"), do: "Deleted user"
  def label("delete_conversation"), do: "Deleted conversation"
  def label(other), do: other
end
