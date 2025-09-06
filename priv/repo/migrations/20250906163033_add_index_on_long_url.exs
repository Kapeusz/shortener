defmodule Shortnr.Repo.Migrations.AddIndexOnLongUrl do
  use Ecto.Migration

  def change do
    create index(:urls, [:long_url])
  end
end
