defmodule RumblWeb.User2RegistrationController do
  use RumblWeb, :controller

  alias Rumbl.Accounts2
  alias Rumbl.Accounts2.User2
  alias RumblWeb.User2Auth

  def new(conn, _params) do
    changeset = Accounts2.change_user2_registration(%User2{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"user2" => user2_params}) do
    case Accounts2.register_user2(user2_params) do
      {:ok, user2} ->
        {:ok, _} =
          Accounts2.deliver_user2_confirmation_instructions(
            user2,
            &url(~p"/users2/confirm/#{&1}")
          )

        conn
        |> put_flash(:info, "User2 created successfully.")
        |> User2Auth.log_in_user2(user2)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end
end
