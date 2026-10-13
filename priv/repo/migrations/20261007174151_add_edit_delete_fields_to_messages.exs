defmodule ViraChat.Repo.Migrations.AddEditDeleteFieldsToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :edited_at, :utc_datetime
      add :deleted_at, :utc_datetime
    end
  end
end
