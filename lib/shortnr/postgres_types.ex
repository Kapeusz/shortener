defmodule Shortnr.PostgresTypes do
  @moduledoc "Postgrex types including PostGIS extension."
end

Postgrex.Types.define(
  Shortnr.PostgresTypes,
  [Geo.PostGIS.Extension],
  json: Jason
)
