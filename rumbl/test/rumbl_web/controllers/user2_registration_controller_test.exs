defmodule RumblWeb.User2RegistrationControllerTest do
  use RumblWeb.ConnCase, async: true

  import Rumbl.Accounts2Fixtures

  describe "GET /users2/register" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, ~p"/users2/register")
      response = html_response(conn, 200)
      assert response =~ "Register"
      assert response =~ ~p"/users/log_in"
      assert response =~ ~p"/users/register"
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in_user2(user2_fixture()) |> get(~p"/users2/register")

      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "POST /users2/register" do
    @tag :capture_log
    test "creates account and logs the user2 in", %{conn: conn} do
      email = unique_user2_email()

      conn =
        post(conn, ~p"/users2/register", %{
          "user2" => valid_user2_attributes(email: email)
        })

      assert get_session(conn, :user2_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ email
      assert response =~ ~p"/users/settings"
      assert response =~ ~p"/users/log_out"
    end

    test "render errors for invalid data", %{conn: conn} do
      conn =
        post(conn, ~p"/users2/register", %{
          "user2" => %{"email" => "with spaces", "password" => "too short"}
        })

      response = html_response(conn, 200)
      assert response =~ "Register"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "should be at least 12 character"
    end
  end
end
