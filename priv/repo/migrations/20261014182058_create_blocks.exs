defmodule ViraChat.Repo.Migrations.CreateBlocks do
  use Ecto.Migration

  def change do
    create table(:blocks) do
      add :blocker_id, references(:users, on_delete: :delete_all), null: false
      add :blocked_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:blocks, [:blocker_id, :blocked_id])
    create index(:blocks, [:blocker_id])
    create index(:blocks, [:blocked_id])
  end
end
