defmodule RumblWeb.User2AuthTest do
  use RumblWeb.ConnCase, async: true

  alias Phoenix.LiveView
  alias Rumbl.Accounts2
  alias RumblWeb.User2Auth
  import Rumbl.Accounts2Fixtures

  @remember_me_cookie "_rumbl_web_user2_remember_me"

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, RumblWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{user2: user2_fixture(), conn: conn}
  end

  describe "log_in_user2/3" do
    test "stores the user2 token in the session", %{conn: conn, user2: user2} do
      conn = User2Auth.log_in_user2(conn, user2)
      assert token = get_session(conn, :user2_token)
      assert get_session(conn, :live_socket_id) == "users2_sessions:#{Base.url_encode64(token)}"
      assert redirected_to(conn) == ~p"/"
      assert Accounts2.get_user2_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{conn: conn, user2: user2} do
      conn = conn |> put_session(:to_be_removed, "value") |> User2Auth.log_in_user2(user2)
      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, user2: user2} do
      conn = conn |> put_session(:user2_return_to, "/hello") |> User2Auth.log_in_user2(user2)
      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, user2: user2} do
      conn = conn |> fetch_cookies() |> User2Auth.log_in_user2(user2, %{"remember_me" => "true"})
      assert get_session(conn, :user2_token) == conn.cookies[@remember_me_cookie]

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :user2_token)
      assert max_age == 5_184_000
    end
  end

  describe "logout_user2/1" do
    test "erases session and cookies", %{conn: conn, user2: user2} do
      user2_token = Accounts2.generate_user2_session_token(user2)

      conn =
        conn
        |> put_session(:user2_token, user2_token)
        |> put_req_cookie(@remember_me_cookie, user2_token)
        |> fetch_cookies()
        |> User2Auth.log_out_user2()

      refute get_session(conn, :user2_token)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
      refute Accounts2.get_user2_by_session_token(user2_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "users2_sessions:abcdef-token"
      RumblWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> User2Auth.log_out_user2()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works even if user2 is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> User2Auth.log_out_user2()
      refute get_session(conn, :user2_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "fetch_current_user2/2" do
    test "authenticates user2 from session", %{conn: conn, user2: user2} do
      user2_token = Accounts2.generate_user2_session_token(user2)
      conn = conn |> put_session(:user2_token, user2_token) |> User2Auth.fetch_current_user2([])
      assert conn.assigns.current_user2.id == user2.id
    end

    test "authenticates user2 from cookies", %{conn: conn, user2: user2} do
      logged_in_conn =
        conn |> fetch_cookies() |> User2Auth.log_in_user2(user2, %{"remember_me" => "true"})

      user2_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> User2Auth.fetch_current_user2([])

      assert conn.assigns.current_user2.id == user2.id
      assert get_session(conn, :user2_token) == user2_token

      assert get_session(conn, :live_socket_id) ==
               "users2_sessions:#{Base.url_encode64(user2_token)}"
    end

    test "does not authenticate if data is missing", %{conn: conn, user2: user2} do
      _ = Accounts2.generate_user2_session_token(user2)
      conn = User2Auth.fetch_current_user2(conn, [])
      refute get_session(conn, :user2_token)
      refute conn.assigns.current_user2
    end
  end

  describe "on_mount: mount_current_user2" do
    test "assigns current_user2 based on a valid user2_token ", %{conn: conn, user2: user2} do
      user2_token = Accounts2.generate_user2_session_token(user2)
      session = conn |> put_session(:user2_token, user2_token) |> get_session()

      {:cont, updated_socket} =
        User2Auth.on_mount(:mount_current_user2, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_user2.id == user2.id
    end

    test "assigns nil to current_user2 assign if there isn't a valid user2_token ", %{conn: conn} do
      user2_token = "invalid_token"
      session = conn |> put_session(:user2_token, user2_token) |> get_session()

      {:cont, updated_socket} =
        User2Auth.on_mount(:mount_current_user2, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_user2 == nil
    end

    test "assigns nil to current_user2 assign if there isn't a user2_token", %{conn: conn} do
      session = conn |> get_session()

      {:cont, updated_socket} =
        User2Auth.on_mount(:mount_current_user2, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_user2 == nil
    end
  end

  describe "on_mount: ensure_authenticated" do
    test "authenticates current_user2 based on a valid user2_token ", %{conn: conn, user2: user2} do
      user2_token = Accounts2.generate_user2_session_token(user2)
      session = conn |> put_session(:user2_token, user2_token) |> get_session()

      {:cont, updated_socket} =
        User2Auth.on_mount(:ensure_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_user2.id == user2.id
    end

    test "redirects to login page if there isn't a valid user2_token ", %{conn: conn} do
      user2_token = "invalid_token"
      session = conn |> put_session(:user2_token, user2_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: RumblWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = User2Auth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_user2 == nil
    end

    test "redirects to login page if there isn't a user2_token ", %{conn: conn} do
      session = conn |> get_session()

      socket = %LiveView.Socket{
        endpoint: RumblWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = User2Auth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_user2 == nil
    end
  end

  describe "on_mount: :redirect_if_user2_is_authenticated" do
    test "redirects if there is an authenticated  user2 ", %{conn: conn, user2: user2} do
      user2_token = Accounts2.generate_user2_session_token(user2)
      session = conn |> put_session(:user2_token, user2_token) |> get_session()

      assert {:halt, _updated_socket} =
               User2Auth.on_mount(
                 :redirect_if_user2_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end

    test "Don't redirect is there is no authenticated user2", %{conn: conn} do
      session = conn |> get_session()

      assert {:cont, _updated_socket} =
               User2Auth.on_mount(
                 :redirect_if_user2_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end
  end

  describe "redirect_if_user2_is_authenticated/2" do
    test "redirects if user2 is authenticated", %{conn: conn, user2: user2} do
      conn = conn |> assign(:current_user2, user2) |> User2Auth.redirect_if_user2_is_authenticated([])
      assert conn.halted
      assert redirected_to(conn) == ~p"/"
    end

    test "does not redirect if user2 is not authenticated", %{conn: conn} do
      conn = User2Auth.redirect_if_user2_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end

  describe "require_authenticated_user2/2" do
    test "redirects if user2 is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> User2Auth.require_authenticated_user2([])
      assert conn.halted

      assert redirected_to(conn) == ~p"/users2/log_in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> User2Auth.require_authenticated_user2([])

      assert halted_conn.halted
      assert get_session(halted_conn, :user2_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> User2Auth.require_authenticated_user2([])

      assert halted_conn.halted
      assert get_session(halted_conn, :user2_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> User2Auth.require_authenticated_user2([])

      assert halted_conn.halted
      refute get_session(halted_conn, :user2_return_to)
    end

    test "does not redirect if user2 is authenticated", %{conn: conn, user2: user2} do
      conn = conn |> assign(:current_user2, user2) |> User2Auth.require_authenticated_user2([])
      refute conn.halted
      refute conn.status
    end
  end
end
