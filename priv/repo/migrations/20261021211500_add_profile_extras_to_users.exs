defmodule ViraChat.Repo.Migrations.AddProfileExtrasToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :facebook, :string
      add :instagram, :string
      add :linkedin, :string
      add :active_status, :boolean, null: false, default: true
      add :friends_status, :boolean, null: false, default: true
    end
  end
end
