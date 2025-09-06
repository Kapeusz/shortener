defmodule Shortnr.Metrics.RedirectEvent do
  use Ecto.Schema

  @primary_key false
  schema "redirect_events" do
    field :shortened_url, :string
    field :user_agent, :string
    field :ip, :string
    field :inserted_at, :utc_datetime_usec
  end
end
