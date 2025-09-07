defmodule Shortnr.Repo.Migrations.EnablePostgisAndCreateRedirectLocations do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS postgis"

    create table(:redirect_locations) do
      add :shortened_url, :text, null: false
      add :geom, :geometry, null: false
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create index(:redirect_locations, [:shortened_url])
    execute "CREATE INDEX redirect_locations_geom_idx ON redirect_locations USING GIST (geom)"

    execute "ALTER TABLE redirect_locations ADD CONSTRAINT enforce_geom_type CHECK (GeometryType(geom) = 'POINT'::text)"

    execute "ALTER TABLE redirect_locations ADD CONSTRAINT enforce_srid CHECK (ST_SRID(geom) = 4326)"
  end

  def down do
    execute "ALTER TABLE IF EXISTS redirect_locations DROP CONSTRAINT IF EXISTS enforce_srid"
    execute "ALTER TABLE IF EXISTS redirect_locations DROP CONSTRAINT IF EXISTS enforce_geom_type"
    drop table(:redirect_locations)
    execute "DROP EXTENSION IF EXISTS postgis"
  end
end
