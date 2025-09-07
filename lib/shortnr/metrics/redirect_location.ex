defmodule Shortnr.Metrics.RedirectLocation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @type t :: %__MODULE__{
          id: integer(),
          shortened_url: String.t(),
          geom: Geo.geometry(),
          inserted_at: DateTime.t()
        }
  schema "redirect_locations" do
    field :shortened_url, :string
    field :geom, Geo.PostGIS.Geometry
    field :inserted_at, :utc_datetime_usec
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:shortened_url, :geom])
    |> validate_required([:shortened_url, :geom])
  end
end
