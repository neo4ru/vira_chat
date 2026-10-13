defmodule Mix.Tasks.Virachat.MakeSuperuser do
  use Mix.Task
  import Ecto.Query
  alias ViraChat.Repo
  alias ViraChat.Accounts.User

  @shortdoc "Promotes a user to superuser by email"
  @moduledoc """
  Usage: mix virachat.make_superuser user@example.com
  """

  @impl true
  def run([email]) do
    Mix.Task.run("app.start")

    case Repo.one(from u in User, where: u.email == ^email) do
      nil ->
        Mix.shell().error("No user with email: #{email}")

      user ->
        user
        |> Ecto.Changeset.change(role: "superuser", banned_at: nil)
        |> Repo.update!()

        Mix.shell().info("✅ #{email} is now a superuser. Log out and back in to access /admin.")
    end
  end

  def run(_) do
    Mix.shell().error("Usage: mix virachat.make_superuser user@example.com")
  end
end
