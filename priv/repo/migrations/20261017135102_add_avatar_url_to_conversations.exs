defmodule ViraChat.Repo.Migrations.AddAvatarUrlToConversations do
  use Ecto.Migration

  def change do
    alter table(:conversations) do
      add :avatar_url, :string
    end
  end
end
