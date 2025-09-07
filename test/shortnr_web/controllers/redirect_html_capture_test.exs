defmodule ShortnrWeb.RedirectHTMLCaptureTest do
  use ShortnrWeb.ConnCase, async: false

  alias Shortnr.Urls

  setup do
    prev = Application.get_env(:shortnr, :geo_capture, true)
    Application.put_env(:shortnr, :geo_capture, true)
    on_exit(fn -> Application.put_env(:shortnr, :geo_capture, prev) end)
  end

  test "shows capture page when enabled", %{conn: conn} do
    slug = "cap1234"
    long = "https://example.com/capture"
    {:ok, _} = Urls.create_url(%{shortened_url: slug, long_url: long})

    Phoenix.PubSub.subscribe(Shortnr.PubSub, "redirects")

    conn = get(conn, "/#{slug}")
    assert html_response(conn, 200) =~ "Preparing your redirect"
    assert_receive {:redirect, %{slug: ^slug}}, 100
  end
end
