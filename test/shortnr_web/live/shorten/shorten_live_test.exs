defmodule ShortnrWeb.Shorten.ShortenLiveTest do
  use ShortnrWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Shortnr.UrlsFixtures

  alias Shortnr.Urls

  setup :register_and_log_in_admin

  test "renders form and existing urls", %{conn: conn} do
    url = url_fixture(%{long_url: "https://example.com/existing"})

    {:ok, _view, html} = live(conn, "/shorten")
    assert html =~ "Shorten URL"
    assert html =~ url.long_url
    assert html =~ url.shortened_url
  end

  test "validates long_url on change", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/shorten")

    form = element(view, "form[phx-submit=save]")
    html = render_change(form, %{url: %{long_url: "notaurl"}})
    assert html =~ "must start with http or https"
  end

  test "creates short url on submit and lists it", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/shorten")

    long = "https://example.com/new-path"
    form = element(view, "form[phx-submit=save]")
    html = render_submit(form, %{url: %{long_url: long}})

    assert html =~ "Short URL created"

    # Verify created mapping is in DB and rendered
    url = Urls.get_active_by_long_url(long)
    assert url
    assert html =~ url.shortened_url
    assert html =~ url.long_url
  end

  test "increments redirect count on redirect event", %{conn: conn} do
    url = url_fixture(%{long_url: "https://example.com/count"})

    {:ok, view, html} = live(conn, "/shorten")
    assert html =~ url.shortened_url
    assert html =~ "0"

    # Send the event directly to the LiveView
    send(view.pid, {:redirect, %{slug: url.shortened_url}})
    updated = render(view)
    assert updated =~ "1"
  end
end
