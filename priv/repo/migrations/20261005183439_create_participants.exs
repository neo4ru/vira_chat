def change do
  create table(:participants) do
    add :user_id, references(:users, on_delete: :delete_all)
    add :conversation_id, references(:conversations, on_delete: :delete_all)

    timestamps()
  end

  create index(:participants, [:user_id])
  create index(:participants, [:conversation_id])
  create unique_index(:participants, [:user_id, :conversation_id])
end
