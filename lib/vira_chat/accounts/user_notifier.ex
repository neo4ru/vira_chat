defmodule ViraChat.Accounts.UserNotifier do
  import Swoosh.Email

  alias ViraChat.Mailer
  alias ViraChat.Accounts.User

  @from {"ViraChat", "contact@example.com"}

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, text_body, html_body) do
    email =
      new()
      |> to(recipient)
      |> from(@from)
      |> subject(subject)
      |> text_body(text_body)

    email = if html_body, do: html_body(email, html_body), else: email

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(
      user.email,
      "Update email instructions",
      """
      Hi #{user.email},

      You can change your email by visiting the URL below:

      #{url}

      If you didn't request this change, please ignore this.
      """,
      layout(
        "Confirm your new email",
        "Click the button below to confirm your new email address for ViraChat.",
        url,
        "Confirm new email",
        "This link expires in 7 days. If you didn't request this change, please ignore this email."
      )
    )
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    deliver(
      user.email,
      "Reset password instructions",
      """
      Hi #{user.email},

      You can reset your password by visiting the URL below:

      #{url}

      If you didn't request this change, please ignore this.
      """,
      layout(
        "Reset your password",
        "We received a request to reset the password for your ViraChat account.",
        url,
        "Reset my password",
        "This link expires in 24 hours. If you didn't request a password reset, you can safely ignore this email."
      )
    )
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(
      user.email,
      "Log in instructions",
      """
      Hi #{user.email},

      You can log into your account by visiting the URL below:

      #{url}

      If you didn't request this email, please ignore this.
      """,
      layout(
        "Log in to ViraChat",
        "Click the button below to log in to your ViraChat account.",
        url,
        "Log in",
        "This link expires in 15 minutes. If you didn't request this email, please ignore it."
      )
    )
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(
      user.email,
      "Confirmation instructions",
      """
      Hi #{user.email},

      You can confirm your account by visiting the URL below:

      #{url}

      If you didn't create an account with us, please ignore this.
      """,
      layout(
        "Confirm your email",
        "Click the button below to confirm your email address and activate your ViraChat account.",
        url,
        "Confirm my account",
        "This link expires in 15 minutes. If you didn't create an account, please ignore this email."
      )
    )
  end

  # A minimal, email-client-friendly HTML layout with a clickable call to action.
  defp layout(title, intro, url, cta, footnote) do
    """
    <!DOCTYPE html>
    <html>
      <body style="margin:0;padding:0;background:#f8fafc;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
        <div style="max-width:480px;margin:0 auto;padding:32px 16px;">
          <div style="background:#ffffff;border:1px solid #e2e8f0;border-radius:12px;padding:32px;color:#334155;">
            <div style="font-size:18px;font-weight:700;color:#4f46e5;margin-bottom:24px;">ViraChat</div>
            <h1 style="font-size:20px;line-height:1.3;margin:0 0 12px;color:#0f172a;">#{title}</h1>
            <p style="font-size:15px;line-height:1.6;margin:0 0 24px;">#{intro}</p>
            <p style="margin:0 0 28px;">
              <a href="#{url}" style="display:inline-block;background:#4f46e5;color:#ffffff;text-decoration:none;font-weight:600;font-size:15px;padding:12px 22px;border-radius:8px;">#{cta}</a>
            </p>
            <p style="font-size:13px;line-height:1.6;color:#64748b;margin:0 0 8px;">Or copy and paste this link into your browser:</p>
            <p style="font-size:13px;line-height:1.6;margin:0 0 28px;word-break:break-all;">
              <a href="#{url}" style="color:#4f46e5;">#{url}</a>
            </p>
            <p style="font-size:13px;line-height:1.6;color:#64748b;margin:0;">#{footnote}</p>
          </div>
          <p style="text-align:center;font-size:12px;color:#94a3b8;margin:20px 0 0;">ViraChat &middot; Built with Elixir &amp; Phoenix</p>
        </div>
      </body>
    </html>
    """
  end
end
