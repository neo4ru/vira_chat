defmodule ViraChat.Repo.Migrations.AddLastReadAtToParticipants do
  use Ecto.Migration

  def change do
    alter table(:participants) do
      add :last_read_at, :utc_datetime
    end
  end
end
