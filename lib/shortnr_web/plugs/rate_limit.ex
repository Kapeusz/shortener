defmodule ShortnrWeb.Plugs.RateLimit do
  @moduledoc """
  Simple rate-limiting Plug using Hammer.

  Responds with 429 on limit exceeded.
  """
  @behaviour Plug
  import Plug.Conn

  def init(opts) do
    %{
      label: Keyword.fetch!(opts, :label),
      limit: Keyword.fetch!(opts, :limit),
      scale_ms: Keyword.get(opts, :scale_ms, 60_000),
      by: Keyword.get(opts, :by, :ip)
    }
  end

  def call(conn, %{label: label, limit: limit, scale_ms: scale_ms, by: by}) do
    # Disable in test
    if Application.get_env(:shortnr, :rate_limit, true) == false do
      conn
    else
      key = bucket_key(conn, by, label)

      case Hammer.check_rate(key, scale_ms, limit) do
        {:allow, _count} ->
          conn

        {:deny, _limit} ->
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(429, ~s({"error":"rate_limited"}))
          |> halt()
      end
    end
  end

  defp bucket_key(conn, :ip, label) do
    ip = ip_from_conn(conn)
    label <> ":ip:" <> ip
  end

  defp bucket_key(conn, {:header, name}, label) when is_binary(name) do
    val = get_req_header(conn, name) |> List.first() || ""
    label <> ":h:" <> name <> ":" <> val
  end

  defp bucket_key(conn, {:header, name}, label) when is_atom(name) do
    bucket_key(conn, {:header, Atom.to_string(name)}, label)
  end

  defp ip_from_conn(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [ips | _] when is_binary(ips) and ips != "" ->
        ips
        |> String.split(",")
        |> List.first()
        |> String.trim()

      _ ->
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end
end
