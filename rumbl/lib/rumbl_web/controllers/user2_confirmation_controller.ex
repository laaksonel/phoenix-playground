defmodule RumblWeb.User2ConfirmationController do
  use RumblWeb, :controller

  alias Rumbl.Accounts2

  def new(conn, _params) do
    render(conn, :new)
  end

  def create(conn, %{"user2" => %{"email" => email}}) do
    if user2 = Accounts2.get_user2_by_email(email) do
      Accounts2.deliver_user2_confirmation_instructions(
        user2,
        &url(~p"/users2/confirm/#{&1}")
      )
    end

    conn
    |> put_flash(
      :info,
      "If your email is in our system and it has not been confirmed yet, " <>
        "you will receive an email with instructions shortly."
    )
    |> redirect(to: ~p"/")
  end

  def edit(conn, %{"token" => token}) do
    render(conn, :edit, token: token)
  end

  # Do not log in the user2 after confirmation to avoid a
  # leaked token giving the user2 access to the account.
  def update(conn, %{"token" => token}) do
    case Accounts2.confirm_user2(token) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "User2 confirmed successfully.")
        |> redirect(to: ~p"/")

      :error ->
        # If there is a current user2 and the account was already confirmed,
        # then odds are that the confirmation link was already visited, either
        # by some automation or by the user2 themselves, so we redirect without
        # a warning message.
        case conn.assigns do
          %{current_user2: %{confirmed_at: confirmed_at}} when not is_nil(confirmed_at) ->
            redirect(conn, to: ~p"/")

          %{} ->
            conn
            |> put_flash(:error, "User2 confirmation link is invalid or it has expired.")
            |> redirect(to: ~p"/")
        end
    end
  end
end
