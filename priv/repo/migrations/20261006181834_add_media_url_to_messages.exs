defmodule ViraChat.Repo.Migrations.AddMediaUrlToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :media_url, :string
    end
  end
end
