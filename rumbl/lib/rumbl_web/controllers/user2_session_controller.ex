defmodule RumblWeb.User2SessionController do
  use RumblWeb, :controller

  alias Rumbl.Accounts2
  alias RumblWeb.User2Auth

  def new(conn, _params) do
    render(conn, :new, error_message: nil)
  end

  def create(conn, %{"user2" => user2_params}) do
    %{"email" => email, "password" => password} = user2_params

    if user2 = Accounts2.get_user2_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> User2Auth.log_in_user2(user2, user2_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      render(conn, :new, error_message: "Invalid email or password")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> User2Auth.log_out_user2()
  end
end
