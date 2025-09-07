defmodule ShortnrWeb.GeoController do
  use ShortnrWeb, :controller

  alias Shortnr.Metrics.Geo
  require Logger

  def create(conn, %{"slug" => slug, "lat" => lat, "lng" => lng}) do
    with {:ok, lat} <- cast_float(lat),
         {:ok, lng} <- cast_float(lng),
         true <- lat >= -90 and lat <= 90 and lng >= -180 and lng <= 180 do
      # Do not crash user flow if DB errors
      _ = safe_insert(slug, lat, lng)
      send_resp(conn, 204, "")
    else
      _ -> send_resp(conn, 400, "invalid")
    end
  end

  defp cast_float(v) when is_binary(v) do
    case Float.parse(v) do
      {f, _} -> {:ok, f}
      :error -> :error
    end
  end

  defp cast_float(v) when is_number(v), do: {:ok, v * 1.0}
  defp cast_float(_), do: :error

  defp safe_insert(slug, lat, lng) do
    try do
      rec = Geo.insert_location!(slug, lat, lng)
      Logger.debug("stored geolocation for #{slug}: #{inspect({lat, lng})}")

      Phoenix.PubSub.broadcast(
        Shortnr.PubSub,
        "geo:#{slug}",
        {:geo, %{slug: slug, lat: lat, lng: lng}}
      )

      rec
    rescue
      e ->
        Logger.warning("failed to store geolocation for #{slug}: #{Exception.message(e)}")
        :ok
    end
  end
end
