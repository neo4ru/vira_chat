defmodule ViraChat.Statuses.StatusView do
  use Ecto.Schema
  import Ecto.Changeset

  schema "status_views" do
    belongs_to :status, ViraChat.Statuses.Status
    belongs_to :viewer, ViraChat.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(status_view, attrs) do
    status_view
    |> cast(attrs, [:status_id, :viewer_id])
    |> validate_required([:status_id, :viewer_id])
    |> unique_constraint([:status_id, :viewer_id])
  end
end
