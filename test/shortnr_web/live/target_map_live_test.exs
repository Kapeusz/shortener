defmodule ShortnrWeb.TargetMapLiveTest do
  use ShortnrWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Shortnr.UrlsFixtures

  alias Shortnr.Metrics.Geo

  setup :register_and_log_in_admin

  setup do
    case Ecto.Adapters.SQL.query(Shortnr.Repo, "SELECT PostGIS_Version()", []) do
      {:ok, _} -> :ok
      _ -> {:skip, "PostGIS not available"}
    end
  end

  test "renders map and updates on geo broadcasts", %{conn: conn} do
    url = url_fixture(%{long_url: "https://example.com/t"})
    slug = url.shortened_url

    # preload one point
    _ = Geo.insert_location!(slug, 52.1, 21.0)

    {:ok, view, html} = live(conn, ~p"/admins/targets/#{slug}")
    assert html =~ "Locations for #{slug}"
    assert html =~ "Markers found: 1"

    # Simulate a live insert broadcast
    Phoenix.PubSub.broadcast(
      Shortnr.PubSub,
      "geo:#{slug}",
      {:geo, %{slug: slug, lat: 50.0, lng: 19.9}}
    )

    updated = render(view)
    assert updated =~ "Markers found: 2"
  end
end
