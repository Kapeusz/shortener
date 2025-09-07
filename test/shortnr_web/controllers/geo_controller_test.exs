defmodule ShortnrWeb.GeoControllerTest do
  use ShortnrWeb.ConnCase, async: true

  import Ecto.Query
  alias Shortnr.Repo
  alias Shortnr.Metrics.RedirectLocation

  setup do
    # Skip if PostGIS is not available in the test DB
    case Ecto.Adapters.SQL.query(Shortnr.Repo, "SELECT PostGIS_Version()", []) do
      {:ok, _} -> :ok
      _ -> {:skip, "PostGIS not available"}
    end
  end

  test "accepts geolocation and stores record + broadcasts", %{conn: conn} do
    slug = "test-slug"
    Phoenix.PubSub.subscribe(Shortnr.PubSub, "geo:#{slug}")

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(~p"/geo", %{slug: slug, lat: 10.5, lng: 20.25})

    assert response(conn, 204)

    rec = Repo.one(from rl in RedirectLocation, where: rl.shortened_url == ^slug, limit: 1)
    assert rec
    assert match?(%Geo.Point{coordinates: {20.25, 10.5}, srid: 4326}, rec.geom)

    assert_receive {:geo, %{slug: ^slug, lat: 10.5, lng: 20.25}}, 200
  end

  test "rejects invalid coordinates with 400", %{conn: conn} do
    slug = "bad-coords"

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(~p"/geo", %{slug: slug, lat: 200, lng: 10})

    assert response(conn, 400)
  end
end
