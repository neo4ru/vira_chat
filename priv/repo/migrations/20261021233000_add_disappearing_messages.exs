defmodule ViraChat.Repo.Migrations.AddDisappearingMessages do
  use Ecto.Migration

  def change do
    alter table(:conversations) do
      add :disappearing_seconds, :integer, null: false, default: 0
    end

    alter table(:messages) do
      add :expires_at, :utc_datetime
    end

    create index(:messages, [:expires_at])
  end
end
