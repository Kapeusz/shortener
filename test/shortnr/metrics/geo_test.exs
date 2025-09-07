defmodule Shortnr.Metrics.GeoTest do
  use Shortnr.DataCase, async: true

  alias Shortnr.Metrics.Geo, as: MetricsGeo

  setup do
    case Ecto.Adapters.SQL.query(Shortnr.Repo, "SELECT PostGIS_Version()", []) do
      {:ok, _} -> :ok
      _ -> {:skip, "PostGIS not available"}
    end
  end

  test "insert_location! stores point with 4326 and lon/lat order" do
    slug = "geo-insert"
    rec = MetricsGeo.insert_location!(slug, 1.0, 2.0)
    assert rec.shortened_url == slug
    assert match?(%Elixir.Geo.Point{coordinates: {2.0, 1.0}, srid: 4326}, rec.geom)
  end
end
