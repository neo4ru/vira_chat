defmodule ViraChat.Repo.Migrations.AddLinkPreviewAndForwardedToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :link_preview, :map
      add :forwarded_from_id, references(:messages, on_delete: :nilify_all)
    end

    create index(:messages, [:forwarded_from_id])
  end
end
