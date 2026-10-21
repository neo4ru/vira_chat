defmodule ViraChatWeb.UserLive.ResetPasswordTest do
  use ViraChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import ViraChat.AccountsFixtures

  alias ViraChat.Accounts

  describe "request reset link" do
    test "sends an email for an existing user", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/reset-password")

      {:ok, _lv, html} =
        lv
        |> form("#reset_password_form", user: %{email: user.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"

      assert ViraChat.Repo.get_by!(ViraChat.Accounts.UserToken, user_id: user.id).context ==
               "reset_password"
    end

    test "does not disclose if the user is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password")

      {:ok, _lv, html} =
        lv
        |> form("#reset_password_form", user: %{email: "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"
    end
  end

  describe "reset password" do
    test "resets the password with a valid token", %{conn: conn} do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      {:ok, lv, html} = live(conn, ~p"/users/reset-password/#{token}")

      assert html =~ "Choose a new password"

      result =
        lv
        |> form("#reset_password_form",
          user: %{
            password: "a brand new password",
            password_confirmation: "a brand new password"
          }
        )
        |> render_submit()

      {:ok, _lv, html} = follow_redirect(result, conn, ~p"/users/log-in")
      assert html =~ "Password reset successfully"

      assert Accounts.get_user_by_email_and_password(user.email, "a brand new password")
    end

    test "renders an error for an invalid token", %{conn: conn} do
      {:ok, _lv, html} =
        live(conn, ~p"/users/reset-password/invalid-token")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Reset password link is invalid or it has expired"
    end
  end
end
