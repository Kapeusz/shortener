defmodule Shortnr.Repo do
  use Ecto.Repo,
    otp_app: :shortnr,
    adapter: Ecto.Adapters.Postgres
end
