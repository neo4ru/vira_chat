defmodule ViraChat.Repo.Migrations.AddClearedAtToParticipants do
  use Ecto.Migration

  def change do
    alter table(:participants) do
      add :cleared_at, :utc_datetime
    end
  end
end
