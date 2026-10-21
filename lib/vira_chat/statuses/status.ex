defmodule ViraChat.Statuses.Status do
  use Ecto.Schema
  import Ecto.Changeset

  schema "statuses" do
    field :content, :string
    field :media_url, :string
    field :background, :string, default: "#6338F6"
    field :expires_at, :utc_datetime

    belongs_to :user, ViraChat.Accounts.User
    has_many :views, ViraChat.Statuses.StatusView, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  def changeset(status, attrs) do
    status
    |> cast(attrs, [:content, :media_url, :background, :expires_at, :user_id])
    |> validate_required([:user_id, :expires_at])
    |> validate_length(:content, max: 300)
  end
end
