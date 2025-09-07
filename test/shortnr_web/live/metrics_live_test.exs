defmodule ShortnrWeb.MetricsLiveTest do
  use ShortnrWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Shortnr.UrlsFixtures

  setup :register_and_log_in_admin

  test "renders and updates on redirect events", %{conn: conn} do
    u = url_fixture(%{long_url: "https://example.com/m"})

    {:ok, view, html} = live(conn, "/admins/metrics")
    assert html =~ "Usage Metrics"

    # Initially may not include our slug if no events yet
    refute html =~ u.shortened_url

    # Broadcast of events
    Phoenix.PubSub.broadcast(
      Shortnr.PubSub,
      "redirects",
      {:redirect, %{slug: u.shortened_url, user_agent: "Mozilla/5.0 Chrome/120", ip: "1.2.3.4"}}
    )

    Phoenix.PubSub.broadcast(
      Shortnr.PubSub,
      "redirects",
      {:redirect, %{slug: u.shortened_url, user_agent: "Mozilla/5.0 Chrome/120", ip: "1.2.3.4"}}
    )

    # Re-render should now include slug and counts
    updated = render(view)
    assert updated =~ u.shortened_url
    assert updated =~ "Chrome"
    assert updated =~ "Public"
  end
end
