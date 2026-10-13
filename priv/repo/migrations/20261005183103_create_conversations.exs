defmodule ViraChat.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    create table(:conversations) do
      add :type, :string
      add :title, :string

      timestamps(type: :utc_datetime)
    end
  end
end
