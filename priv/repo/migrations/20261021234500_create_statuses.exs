defmodule ViraChat.Repo.Migrations.CreateStatuses do
  use Ecto.Migration

  def change do
    create table(:statuses) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :content, :text
      add :media_url, :string
      add :background, :string, null: false, default: "#6338F6"
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:statuses, [:expires_at])
    create index(:statuses, [:user_id])

    create table(:status_views) do
      add :status_id, references(:statuses, on_delete: :delete_all), null: false
      add :viewer_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:status_views, [:status_id, :viewer_id])
  end
end
