defmodule RumblWeb.User2SettingsController do
  use RumblWeb, :controller

  alias Rumbl.Accounts2
  alias RumblWeb.User2Auth

  plug :assign_email_and_password_changesets

  def edit(conn, _params) do
    render(conn, :edit)
  end

  def update(conn, %{"action" => "update_email"} = params) do
    %{"current_password" => password, "user2" => user2_params} = params
    user2 = conn.assigns.current_user2

    case Accounts2.apply_user2_email(user2, password, user2_params) do
      {:ok, applied_user2} ->
        Accounts2.deliver_user2_update_email_instructions(
          applied_user2,
          user2.email,
          &url(~p"/users2/settings/confirm_email/#{&1}")
        )

        conn
        |> put_flash(
          :info,
          "A link to confirm your email change has been sent to the new address."
        )
        |> redirect(to: ~p"/users2/settings")

      {:error, changeset} ->
        render(conn, :edit, email_changeset: changeset)
    end
  end

  def update(conn, %{"action" => "update_password"} = params) do
    %{"current_password" => password, "user2" => user2_params} = params
    user2 = conn.assigns.current_user2

    case Accounts2.update_user2_password(user2, password, user2_params) do
      {:ok, user2} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:user2_return_to, ~p"/users2/settings")
        |> User2Auth.log_in_user2(user2)

      {:error, changeset} ->
        render(conn, :edit, password_changeset: changeset)
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    case Accounts2.update_user2_email(conn.assigns.current_user2, token) do
      :ok ->
        conn
        |> put_flash(:info, "Email changed successfully.")
        |> redirect(to: ~p"/users2/settings")

      :error ->
        conn
        |> put_flash(:error, "Email change link is invalid or it has expired.")
        |> redirect(to: ~p"/users2/settings")
    end
  end

  defp assign_email_and_password_changesets(conn, _opts) do
    user2 = conn.assigns.current_user2

    conn
    |> assign(:email_changeset, Accounts2.change_user2_email(user2))
    |> assign(:password_changeset, Accounts2.change_user2_password(user2))
  end
end
