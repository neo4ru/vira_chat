defmodule ViraChat.Repo.Migrations.CreateCallLogs do
  use Ecto.Migration

  def change do
    create table(:call_logs) do
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
      add :caller_id, references(:users, on_delete: :delete_all), null: false
      add :callee_id, references(:users, on_delete: :delete_all), null: false
      add :call_type, :string, null: false, default: "voice"
      add :status, :string, null: false, default: "missed"
      add :duration_seconds, :integer, null: false, default: 0
      add :started_at, :utc_datetime
      add :answered_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:call_logs, [:caller_id])
    create index(:call_logs, [:callee_id])
    create index(:call_logs, [:inserted_at])
  end
end
