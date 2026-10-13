defmodule ViraChat.Repo.Migrations.AddAdminFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :string, null: false, default: "user"
      add :banned_at, :utc_datetime
    end

    create index(:users, [:role])
  end
end
