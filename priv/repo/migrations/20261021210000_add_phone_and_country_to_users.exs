defmodule ViraChat.Repo.Migrations.AddPhoneAndCountryToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :phone_country_code, :string
      add :phone, :string
      add :country, :string
    end
  end
end
