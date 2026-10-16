defmodule ViraChat.Repo.Migrations.AddDeliveredAtToParticipants do
  use Ecto.Migration

  def change do
    alter table(:participants) do
      add :delivered_at, :utc_datetime
    end
  end
end
