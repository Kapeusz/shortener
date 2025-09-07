defmodule ShortnrWeb.Plugs.CORS do
  @moduledoc """
  Conditional CORS for the API, backed by `CORSPlug`.

  Reads allowed origins from `Application.get_env(:shortnr, :cors_origins, [])`.
  If empty, it no-ops. Otherwise, it enables CORS with safe defaults.
  """
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    origins = Application.get_env(:shortnr, :cors_origins, [])

    case origins do
      [] ->
        conn

      origins when is_list(origins) ->
        opts =
          CORSPlug.init(
            origin: origins,
            methods: ["GET", "POST", "OPTIONS"],
            headers: ["content-type", "authorization"],
            expose: [],
            credentials: false,
            max_age: 86_400
          )

        CORSPlug.call(conn, opts)
    end
  end
end
