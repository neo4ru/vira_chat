defmodule ViraChat.Repo.Migrations.AddRoleToParticipants do
  use Ecto.Migration

  def change do
    alter table(:participants) do
      add :role, :string, null: false, default: "member"
    end

    create index(:participants, [:role])
  end
end
