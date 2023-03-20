defmodule RumblWeb.User2ConfirmationControllerTest do
  use RumblWeb.ConnCase, async: true

  alias Rumbl.Accounts2
  alias Rumbl.Repo
  import Rumbl.Accounts2Fixtures

  setup do
    %{user2: user2_fixture()}
  end

  describe "GET /users2/confirm" do
    test "renders the resend confirmation page", %{conn: conn} do
      conn = get(conn, ~p"/users2/confirm")
      response = html_response(conn, 200)
      assert response =~ "Resend confirmation instructions"
    end
  end

  describe "POST /users2/confirm" do
    @tag :capture_log
    test "sends a new confirmation token", %{conn: conn, user2: user2} do
      conn =
        post(conn, ~p"/users2/confirm", %{
          "user2" => %{"email" => user2.email}
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.get_by!(Accounts2.User2Token, user2_id: user2.id).context == "confirm"
    end

    test "does not send confirmation token if User2 is confirmed", %{conn: conn, user2: user2} do
      Repo.update!(Accounts2.User2.confirm_changeset(user2))

      conn =
        post(conn, ~p"/users2/confirm", %{
          "user2" => %{"email" => user2.email}
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      refute Repo.get_by(Accounts2.User2Token, user2_id: user2.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/users2/confirm", %{
          "user2" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.all(Accounts2.User2Token) == []
    end
  end

  describe "GET /users2/confirm/:token" do
    test "renders the confirmation page", %{conn: conn} do
      token_path = ~p"/users2/confirm/some-token"
      conn = get(conn, token_path)
      response = html_response(conn, 200)
      assert response =~ "Confirm account"

      assert response =~ "action=\"#{token_path}\""
    end
  end

  describe "POST /users2/confirm/:token" do
    test "confirms the given token once", %{conn: conn, user2: user2} do
      token =
        extract_user2_token(fn url ->
          Accounts2.deliver_user2_confirmation_instructions(user2, url)
        end)

      conn = post(conn, ~p"/users2/confirm/#{token}")
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "User2 confirmed successfully"

      assert Accounts2.get_user2!(user2.id).confirmed_at
      refute get_session(conn, :user2_token)
      assert Repo.all(Accounts2.User2Token) == []

      # When not logged in
      conn = post(conn, ~p"/users2/confirm/#{token}")
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "User2 confirmation link is invalid or it has expired"

      # When logged in
      conn =
        build_conn()
        |> log_in_user2(user2)
        |> post(~p"/users2/confirm/#{token}")

      assert redirected_to(conn) == ~p"/"
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, user2: user2} do
      conn = post(conn, ~p"/users2/confirm/oops")
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "User2 confirmation link is invalid or it has expired"

      refute Accounts2.get_user2!(user2.id).confirmed_at
    end
  end
end
