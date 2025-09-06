defmodule Shortnr.Metrics.Collector do
  @moduledoc "Collects redirect events via PubSub and batches inserts to Postgres."
  use GenServer
  require Logger
  alias Shortnr.Repo

  @topic "redirects"
  @flush_interval_ms 1_000
  @max_batch 1_000

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(Shortnr.PubSub, @topic)
    state = %{buf: [], timer: schedule_flush()}
    {:ok, state}
  end

  @impl true
  def handle_info({:redirect, payload}, %{buf: buf} = state) when is_map(payload) do
    event = to_row(payload)
    buf = [event | buf]
    state = %{state | buf: buf}

    if length(buf) >= @max_batch do
      {:noreply, flush(state)}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:flush, state), do: {:noreply, flush(state)}

  defp schedule_flush, do: Process.send_after(self(), :flush, @flush_interval_ms)

  defp flush(%{buf: []} = state) do
    %{state | timer: reschedule(state)}
  end

  defp flush(%{buf: buf} = state) do
    rows = Enum.reverse(buf)
    now = DateTime.utc_now()

    entries =
      for %{slug: slug, user_agent: ua, ip: ip, at: at} <- rows do
        %{shortened_url: slug, user_agent: ua, ip: ip, inserted_at: at || now}
      end

    try do
      Repo.insert_all("redirect_events", entries, on_conflict: :nothing)
    rescue
      e ->
        if Code.ensure_loaded?(Mix) and Mix.env() == :test do
          Logger.debug("redirect_events insert_all failed (test sandbox): #{inspect(e)}")
        else
          Logger.error("redirect_events insert_all failed: #{inspect(e)}")
        end
    end

    # Increment redirect_count in urls table per slug (batched per flush)
    counts =
      rows
      |> Enum.reduce(%{}, fn %{slug: slug}, acc -> Map.update(acc, slug, 1, &(&1 + 1)) end)

    Enum.each(counts, fn {slug, cnt} ->
      # One UPDATE per slug
      try do
        _ =
          Repo.query(
            "UPDATE urls SET redirect_count = redirect_count + $1, updated_at = now() WHERE shortened_url = $2",
            [cnt, slug]
          )
      rescue
        e ->
          if Code.ensure_loaded?(Mix) and Mix.env() == :test do
            Logger.debug("urls counter update failed (test sandbox): #{inspect(e)}")
          else
            Logger.error("urls counter update failed: #{inspect(e)}")
          end
      end
    end)

    %{buf: [], timer: reschedule(state)}
  end

  defp reschedule(%{timer: t}) when is_reference(t) do
    Process.cancel_timer(t)
    schedule_flush()
  end

  defp to_row(%{slug: slug} = m) do
    %{
      slug: slug,
      user_agent: Map.get(m, :user_agent) || Map.get(m, "user_agent"),
      ip: Map.get(m, :ip) || Map.get(m, "ip"),
      at: Map.get(m, :at) || Map.get(m, "at")
    }
  end
end
