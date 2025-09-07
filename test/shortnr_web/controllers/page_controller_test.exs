defmodule ShortnrWeb.PageControllerTest do
  use ShortnrWeb.ConnCase

  test "GET / shows login for unauthenticated", %{conn: conn} do
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)
    assert body =~ "Log in to account"
  end
end
