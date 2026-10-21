defmodule ViraChat.Accounts.UserNotifierTest do
  use ExUnit.Case, async: true

  alias ViraChat.Accounts.{User, UserNotifier}

  test "reset password email contains a clickable link" do
    url = "http://localhost:4000/users/reset-password/token"

    assert {:ok, email} =
             UserNotifier.deliver_reset_password_instructions(%User{email: "neo@example.com"}, url)

    assert email.html_body =~ ~s(href="#{url}")
    assert email.html_body =~ "Reset my password"
    assert email.text_body =~ url
  end

  test "magic link email contains a clickable link" do
    url = "http://localhost:4000/users/log-in/token"

    assert {:ok, email} =
             UserNotifier.deliver_login_instructions(
               %User{email: "neo@example.com", confirmed_at: DateTime.utc_now()},
               url
             )

    assert email.html_body =~ ~s(href="#{url}")
    assert email.text_body =~ url
  end
end
