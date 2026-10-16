defmodule ViraChat.Repo.Migrations.AddControlColumnsToParticipants do
  use Ecto.Migration

  def change do
    alter table(:participants) do
      add :muted_at, :utc_datetime
      add :pinned_at, :utc_datetime
      add :archived_at, :utc_datetime
    end

    create index(:participants, [:pinned_at])
    create index(:participants, [:archived_at])
  end
end
