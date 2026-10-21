defmodule ViraChat.Statuses do
  @moduledoc """
  Short-lived status updates (24 hours) and their viewers.
  """
  import Ecto.Query

  alias ViraChat.Repo
  alias ViraChat.Statuses.Status
  alias ViraChat.Statuses.StatusView

  @ttl_seconds 24 * 60 * 60

  def ttl_seconds, do: @ttl_seconds

  @doc "All currently active statuses with their author and views."
  def list_active do
    now = NaiveDateTime.utc_now()

    Status
    |> where([s], s.expires_at > ^now)
    |> order_by([s], desc: s.inserted_at)
    |> preload([:user, views: :viewer])
    |> Repo.all()
  end

  @doc "A single status with author and views."
  def get_status(id) do
    Status
    |> where([s], s.id == ^id)
    |> preload([:user, views: :viewer])
    |> Repo.one()
  end

  @doc "Creates a status expiring 24 hours from now."
  def create(user_id, attrs) do
    expires_at =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(@ttl_seconds, :second)
      |> NaiveDateTime.truncate(:second)

    %Status{}
    |> Status.changeset(
      Map.merge(attrs, %{user_id: user_id, expires_at: expires_at})
    )
    |> Repo.insert()
  end

  @doc "Marks a status as viewed by the given user (idempotent)."
  def mark_viewed(status_id, viewer_id) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    Repo.insert_all(
      StatusView,
      [%{status_id: status_id, viewer_id: viewer_id, inserted_at: now}],
      on_conflict: :nothing,
      conflict_target: [:status_id, :viewer_id]
    )
  end

  @doc "Deletes one of the user's own statuses."
  def delete(status_id, user_id) do
    case Repo.get(Status, status_id) do
      nil -> {:error, :not_found}
      %Status{user_id: ^user_id} = status -> Repo.delete(status)
      _ -> {:error, :unauthorized}
    end
  end

  @doc "Deletes expired statuses."
  def purge_expired do
    now = NaiveDateTime.utc_now()

    from(s in Status, where: s.expires_at <= ^now)
    |> Repo.delete_all()
  end
end
