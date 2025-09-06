defmodule Shortnr.UrlCache do
  @moduledoc "Per-node ETS cache for long_url -> slug with TTL."
  use GenServer

  @table __MODULE__
  @default_ttl_ms :timer.minutes(30)

  # Public API
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Get cached slug or :miss."
  def get(long_url) when is_binary(long_url) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, long_url) do
      [{^long_url, {slug, exp}}] when exp > now -> {:ok, slug}
      _ -> :miss
    end
  end

  @doc "Put slug with TTL."
  def put(long_url, slug) when is_binary(long_url) and is_binary(slug) do
    ttl = ttl_ms()
    exp = System.monotonic_time(:millisecond) + ttl
    true = :ets.insert(@table, {long_url, {slug, exp}})
    :ok
  end

  # GenServer callbacks
  @impl true
  def init(opts) do
    :ets.new(@table, [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    state = %{ttl_ms: Keyword.get(opts, :ttl_ms, ttl_ms())}
    {:ok, state}
  end

  defp ttl_ms do
    case Application.get_env(:shortnr, :url_cache_ttl_ms) do
      ttl when is_integer(ttl) and ttl > 0 ->
        ttl

      _ ->
        case System.get_env("URL_CACHE_TTL_MS") do
          nil ->
            @default_ttl_ms

          val ->
            case Integer.parse(val) do
              {n, _} when n > 0 -> n
              _ -> @default_ttl_ms
            end
        end
    end
  end
end
