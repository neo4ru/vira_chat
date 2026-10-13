defmodule ViraChat.Repo.Migrations.CreateAdminActions do
  use Ecto.Migration

  def change do
    create table(:admin_actions) do
      add :actor_id, references(:users, on_delete: :nilify_all)
      add :target_user_id, references(:users, on_delete: :nilify_all)
      add :action, :string, null: false
      add :details, :map
      add :inserted_at, :utc_datetime, null: false
    end

    create index(:admin_actions, [:actor_id])
    create index(:admin_actions, [:target_user_id])
    create index(:admin_actions, [:action])
    create index(:admin_actions, [:inserted_at])
  end
end
