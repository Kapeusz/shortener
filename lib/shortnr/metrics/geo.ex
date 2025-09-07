defmodule Shortnr.Metrics.Geo do
  @moduledoc "Helpers for storing and querying redirect geolocations."
  alias Shortnr.Repo
  alias Shortnr.Metrics.RedirectLocation

  @spec insert_location!(slug :: String.t(), lat :: float(), lng :: float()) ::
          RedirectLocation.t()
  def insert_location!(slug, lat, lng) when is_binary(slug) do
    point = %Geo.Point{coordinates: {lng, lat}, srid: 4326}

    %RedirectLocation{}
    |> RedirectLocation.changeset(%{shortened_url: slug, geom: point})
    |> Repo.insert!()
  end

  @spec recent_locations(slug :: String.t(), limit :: pos_integer()) :: [RedirectLocation.t()]
  def recent_locations(slug, limit \\ 100) when is_binary(slug) do
    import Ecto.Query

    Repo.all(
      from rl in RedirectLocation,
        where: rl.shortened_url == ^slug,
        order_by: [desc: rl.inserted_at],
        limit: ^limit
    )
  end
end
