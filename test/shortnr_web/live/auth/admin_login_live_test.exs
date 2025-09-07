defmodule ShortnrWeb.Auth.AdminLoginLiveTest do
  use ShortnrWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Shortnr.AccountsFixtures

  describe "Log in page" do
    test "renders log in page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admins/log_in")

      assert html =~ "Log in"
      refute html =~ "Register"
      refute html =~ "Forgot your password?"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_admin(admin_fixture())
        |> live(~p"/admins/log_in")
        |> follow_redirect(conn, "/shorten")

      assert {:ok, _conn} = result
    end
  end

  describe "admin login" do
    test "redirects if admin login with valid credentials", %{conn: conn} do
      password = "123456789abcd"
      admin = admin_fixture(%{password: password})

      {:ok, lv, _html} = live(conn, ~p"/admins/log_in")

      form =
        form(lv, "#login_form",
          admin: %{email: admin.email, password: password, remember_me: true}
        )

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/shorten"
    end

    test "redirects to login page with a flash error if there are no valid credentials", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/admins/log_in")

      form =
        form(lv, "#login_form",
          admin: %{email: "test@email.com", password: "123456", remember_me: true}
        )

      conn = submit_form(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"

      assert redirected_to(conn) == "/admins/log_in"
    end
  end

  describe "login navigation" do
    test "does not show registration or forgot password links", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/admins/log_in")
      refute html =~ "Register"
      refute html =~ "Forgot your password?"
      refute has_element?(lv, ~s|main a:fl-contains("Sign up")|)
      refute has_element?(lv, ~s|main a:fl-contains("Forgot your password?")|)
    end
  end
end
