defmodule RumblWeb.User2ResetPasswordController do
  use RumblWeb, :controller

  alias Rumbl.Accounts2

  plug :get_user2_by_reset_password_token when action in [:edit, :update]

  def new(conn, _params) do
    render(conn, :new)
  end

  def create(conn, %{"user2" => %{"email" => email}}) do
    if user2 = Accounts2.get_user2_by_email(email) do
      Accounts2.deliver_user2_reset_password_instructions(
        user2,
        &url(~p"/users2/reset_password/#{&1}")
      )
    end

    conn
    |> put_flash(
      :info,
      "If your email is in our system, you will receive instructions to reset your password shortly."
    )
    |> redirect(to: ~p"/")
  end

  def edit(conn, _params) do
    render(conn, :edit, changeset: Accounts2.change_user2_password(conn.assigns.user2))
  end

  # Do not log in the user2 after reset password to avoid a
  # leaked token giving the user2 access to the account.
  def update(conn, %{"user2" => user2_params}) do
    case Accounts2.reset_user2_password(conn.assigns.user2, user2_params) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Password reset successfully.")
        |> redirect(to: ~p"/users2/log_in")

      {:error, changeset} ->
        render(conn, :edit, changeset: changeset)
    end
  end

  defp get_user2_by_reset_password_token(conn, _opts) do
    %{"token" => token} = conn.params

    if user2 = Accounts2.get_user2_by_reset_password_token(token) do
      conn |> assign(:user2, user2) |> assign(:token, token)
    else
      conn
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: ~p"/")
      |> halt()
    end
  end
end
