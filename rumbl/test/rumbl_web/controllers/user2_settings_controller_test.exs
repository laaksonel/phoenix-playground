defmodule RumblWeb.User2SettingsControllerTest do
  use RumblWeb.ConnCase, async: true

  alias Rumbl.Accounts2
  import Rumbl.Accounts2Fixtures

  setup :register_and_log_in_user2

  describe "GET /users2/settings" do
    test "renders settings page", %{conn: conn} do
      conn = get(conn, ~p"/users2/settings")
      response = html_response(conn, 200)
      assert response =~ "Settings"
    end

    test "redirects if user2 is not logged in" do
      conn = build_conn()
      conn = get(conn, ~p"/users2/settings")
      assert redirected_to(conn) == ~p"/users2/log_in"
    end
  end

  describe "PUT /users2/settings (change password form)" do
    test "updates the user2 password and resets tokens", %{conn: conn, user2: user2} do
      new_password_conn =
        put(conn, ~p"/users2/settings", %{
          "action" => "update_password",
          "current_password" => valid_user2_password(),
          "user2" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(new_password_conn) == ~p"/users2/settings"

      assert get_session(new_password_conn, :user2_token) != get_session(conn, :user2_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts2.get_user2_by_email_and_password(user2.email, "new valid password")
    end

    test "does not update password on invalid data", %{conn: conn} do
      old_password_conn =
        put(conn, ~p"/users2/settings", %{
          "action" => "update_password",
          "current_password" => "invalid",
          "user2" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      response = html_response(old_password_conn, 200)
      assert response =~ "Settings"
      assert response =~ "should be at least 12 character(s)"
      assert response =~ "does not match password"
      assert response =~ "is not valid"

      assert get_session(old_password_conn, :user2_token) == get_session(conn, :user2_token)
    end
  end

  describe "PUT /users2/settings (change email form)" do
    @tag :capture_log
    test "updates the user2 email", %{conn: conn, user2: user2} do
      conn =
        put(conn, ~p"/users2/settings", %{
          "action" => "update_email",
          "current_password" => valid_user2_password(),
          "user2" => %{"email" => unique_user2_email()}
        })

      assert redirected_to(conn) == ~p"/users2/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "A link to confirm your email"

      assert Accounts2.get_user2_by_email(user2.email)
    end

    test "does not update email on invalid data", %{conn: conn} do
      conn =
        put(conn, ~p"/users2/settings", %{
          "action" => "update_email",
          "current_password" => "invalid",
          "user2" => %{"email" => "with spaces"}
        })

      response = html_response(conn, 200)
      assert response =~ "Settings"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "is not valid"
    end
  end

  describe "GET /users2/settings/confirm_email/:token" do
    setup %{user2: user2} do
      email = unique_user2_email()

      token =
        extract_user2_token(fn url ->
          Accounts2.deliver_user2_update_email_instructions(%{user2 | email: email}, user2.email, url)
        end)

      %{token: token, email: email}
    end

    test "updates the user2 email once", %{conn: conn, user2: user2, token: token, email: email} do
      conn = get(conn, ~p"/users2/settings/confirm_email/#{token}")
      assert redirected_to(conn) == ~p"/users2/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Email changed successfully"

      refute Accounts2.get_user2_by_email(user2.email)
      assert Accounts2.get_user2_by_email(email)

      conn = get(conn, ~p"/users2/settings/confirm_email/#{token}")

      assert redirected_to(conn) == ~p"/users2/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Email change link is invalid or it has expired"
    end

    test "does not update email with invalid token", %{conn: conn, user2: user2} do
      conn = get(conn, ~p"/users2/settings/confirm_email/oops")
      assert redirected_to(conn) == ~p"/users2/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Email change link is invalid or it has expired"

      assert Accounts2.get_user2_by_email(user2.email)
    end

    test "redirects if user2 is not logged in", %{token: token} do
      conn = build_conn()
      conn = get(conn, ~p"/users2/settings/confirm_email/#{token}")
      assert redirected_to(conn) == ~p"/users2/log_in"
    end
  end
end
