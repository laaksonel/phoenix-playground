defmodule Rumbl.Accounts2.User2Notifier do
  import Swoosh.Email

  alias Rumbl.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Rumbl", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user2, url) do
    deliver(user2.email, "Confirmation instructions", """

    ==============================

    Hi #{user2.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a user2 password.
  """
  def deliver_reset_password_instructions(user2, url) do
    deliver(user2.email, "Reset password instructions", """

    ==============================

    Hi #{user2.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update a user2 email.
  """
  def deliver_update_email_instructions(user2, url) do
    deliver(user2.email, "Update email instructions", """

    ==============================

    Hi #{user2.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end
end
