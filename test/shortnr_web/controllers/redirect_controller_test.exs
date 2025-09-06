defmodule ShortnrWeb.RedirectControllerTest do
  use ShortnrWeb.ConnCase, async: true

  alias Shortnr.Urls

  test "redirects to long URL and publishes event", %{conn: conn} do
    slug = "tst12345"
    long = "https://example.com/long/path"
    {:ok, _} = Urls.create_url(%{long_url: long, shortened_url: slug})

    Phoenix.PubSub.subscribe(Shortnr.PubSub, "redirects")

    conn = get(conn, "/#{slug}")

    assert redirected_to(conn, 302) == long
    assert_receive {:redirect, %{slug: ^slug, user_agent: _, ip: _, at: %DateTime{}}}, 100
  end

  test "unknown slug redirects home with flash", %{conn: conn} do
    conn = get(conn, "/does-not-exist")
    assert redirected_to(conn, 302) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Link not found or expired"
  end
end
