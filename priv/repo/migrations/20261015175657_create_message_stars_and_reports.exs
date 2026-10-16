defmodule ViraChat.Repo.Migrations.CreateMessageStarsAndReports do
  use Ecto.Migration

  def change do
    create table(:message_stars) do
      add :message_id, references(:messages, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:message_stars, [:message_id, :user_id])
    create index(:message_stars, [:user_id])

    create table(:reports) do
      add :reporter_id, references(:users, on_delete: :delete_all), null: false
      add :reported_user_id, references(:users, on_delete: :nilify_all)
      add :message_id, references(:messages, on_delete: :nilify_all)
      add :conversation_id, references(:conversations, on_delete: :nilify_all)
      add :reason, :string, null: false
      add :details, :text
      add :status, :string, default: "pending", null: false
      add :resolved_at, :utc_datetime
      add :resolved_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:reports, [:status])
    create index(:reports, [:reporter_id])
    create index(:reports, [:message_id])
  end
end
