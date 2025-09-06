defmodule Shortnr.Repo.Migrations.CreateRedirectEvents do
  use Ecto.Migration

  def change do
    create table(:redirect_events) do
      add :shortened_url, :text, null: false
      add :user_agent, :text
      add :ip, :text
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create index(:redirect_events, [:shortened_url])
    create index(:redirect_events, [:inserted_at])
  end
end
