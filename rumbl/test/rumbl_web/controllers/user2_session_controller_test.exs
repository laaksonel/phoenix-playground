defmodule RumblWeb.User2SessionControllerTest do
  use RumblWeb.ConnCase, async: true

  import Rumbl.Accounts2Fixtures

  setup do
    %{user2: user2_fixture()}
  end

  describe "GET /users2/log_in" do
    test "renders log in page", %{conn: conn} do
      conn = get(conn, ~p"/users2/log_in")
      response = html_response(conn, 200)
      assert response =~ "Log in"
      assert response =~ ~p"/users/register"
      assert response =~ "Forgot your password?"
    end

    test "redirects if already logged in", %{conn: conn, user2: user2} do
      conn = conn |> log_in_user2(user2) |> get(~p"/users2/log_in")
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "POST /users2/log_in" do
    test "logs the user2 in", %{conn: conn, user2: user2} do
      conn =
        post(conn, ~p"/users2/log_in", %{
          "user2" => %{"email" => user2.email, "password" => valid_user2_password()}
        })

      assert get_session(conn, :user2_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ user2.email
      assert response =~ ~p"/users/settings"
      assert response =~ ~p"/users/log_out"
    end

    test "logs the user2 in with remember me", %{conn: conn, user2: user2} do
      conn =
        post(conn, ~p"/users2/log_in", %{
          "user2" => %{
            "email" => user2.email,
            "password" => valid_user2_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_rumbl_web_user2_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the user2 in with return to", %{conn: conn, user2: user2} do
      conn =
        conn
        |> init_test_session(user2_return_to: "/foo/bar")
        |> post(~p"/users2/log_in", %{
          "user2" => %{
            "email" => user2.email,
            "password" => valid_user2_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "emits error message with invalid credentials", %{conn: conn, user2: user2} do
      conn =
        post(conn, ~p"/users2/log_in", %{
          "user2" => %{"email" => user2.email, "password" => "invalid_password"}
        })

      response = html_response(conn, 200)
      assert response =~ "Log in"
      assert response =~ "Invalid email or password"
    end
  end

  describe "DELETE /users2/log_out" do
    test "logs the user2 out", %{conn: conn, user2: user2} do
      conn = conn |> log_in_user2(user2) |> delete(~p"/users2/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user2_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the user2 is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users2/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user2_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
