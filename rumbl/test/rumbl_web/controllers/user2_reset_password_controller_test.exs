defmodule RumblWeb.User2ResetPasswordControllerTest do
  use RumblWeb.ConnCase, async: true

  alias Rumbl.Accounts2
  alias Rumbl.Repo
  import Rumbl.Accounts2Fixtures

  setup do
    %{user2: user2_fixture()}
  end

  describe "GET /users2/reset_password" do
    test "renders the reset password page", %{conn: conn} do
      conn = get(conn, ~p"/users2/reset_password")
      response = html_response(conn, 200)
      assert response =~ "Forgot your password?"
    end
  end

  describe "POST /users2/reset_password" do
    @tag :capture_log
    test "sends a new reset password token", %{conn: conn, user2: user2} do
      conn =
        post(conn, ~p"/users2/reset_password", %{
          "user2" => %{"email" => user2.email}
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.get_by!(Accounts2.User2Token, user2_id: user2.id).context == "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/users2/reset_password", %{
          "user2" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.all(Accounts2.User2Token) == []
    end
  end

  describe "GET /users2/reset_password/:token" do
    setup %{user2: user2} do
      token =
        extract_user2_token(fn url ->
          Accounts2.deliver_user2_reset_password_instructions(user2, url)
        end)

      %{token: token}
    end

    test "renders reset password", %{conn: conn, token: token} do
      conn = get(conn, ~p"/users2/reset_password/#{token}")
      assert html_response(conn, 200) =~ "Reset password"
    end

    test "does not render reset password with invalid token", %{conn: conn} do
      conn = get(conn, ~p"/users2/reset_password/oops")
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Reset password link is invalid or it has expired"
    end
  end

  describe "PUT /users2/reset_password/:token" do
    setup %{user2: user2} do
      token =
        extract_user2_token(fn url ->
          Accounts2.deliver_user2_reset_password_instructions(user2, url)
        end)

      %{token: token}
    end

    test "resets password once", %{conn: conn, user2: user2, token: token} do
      conn =
        put(conn, ~p"/users2/reset_password/#{token}", %{
          "user2" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(conn) == ~p"/users2/log_in"
      refute get_session(conn, :user2_token)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Password reset successfully"

      assert Accounts2.get_user2_by_email_and_password(user2.email, "new valid password")
    end

    test "does not reset password on invalid data", %{conn: conn, token: token} do
      conn =
        put(conn, ~p"/users2/reset_password/#{token}", %{
          "user2" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert html_response(conn, 200) =~ "something went wrong"
    end

    test "does not reset password with invalid token", %{conn: conn} do
      conn = put(conn, ~p"/users2/reset_password/oops")
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Reset password link is invalid or it has expired"
    end
  end
end
