defmodule Shortnr.Workers.ExpireCleanup do
  @moduledoc "Purges analytics and URL rows for expired short links."
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger
  import Ecto.Query

  alias Shortnr.Repo
  alias Shortnr.Urls.Url
  alias Shortnr.Metrics.{RedirectEvent, RedirectLocation}

  @slug_batch 500

  @impl Oban.Worker
  def perform(_job) do
    now = DateTime.utc_now()

    slugs =
      Repo.all(
        from u in Url,
          where: u.expires_at <= ^now,
          select: u.shortened_url,
          limit: ^@slug_batch
      )

    case slugs do
      [] ->
        :ok

      slugs when is_list(slugs) ->
        result =
          Repo.transaction(fn ->
            {events_deleted, _} =
              Repo.delete_all(from e in RedirectEvent, where: e.shortened_url in ^slugs)

            {loc_deleted, _} =
              Repo.delete_all(from l in RedirectLocation, where: l.shortened_url in ^slugs)

            {urls_deleted, _} =
              Repo.delete_all(
                from u in Url,
                  where: u.shortened_url in ^slugs and u.expires_at <= ^now
              )

            %{events: events_deleted, locations: loc_deleted, urls: urls_deleted}
          end)

        case result do
          {:ok, counts} ->
            Logger.info(
              "expire_cleanup: purged urls=#{counts.urls} events=#{counts.events} locations=#{counts.locations}"
            )

            # If hit the batch limit, there may be more to purge — schedule another run
            if length(slugs) >= @slug_batch do
              :ok = reschedule()
            end

            :ok

          {:error, reason} ->
            Logger.error("expire_cleanup: transaction failed: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  defp reschedule do
    %{}
    |> __MODULE__.new()
    |> Oban.insert()

    :ok
  end
end
