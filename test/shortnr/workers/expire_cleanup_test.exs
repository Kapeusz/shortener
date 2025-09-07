defmodule Shortnr.Workers.ExpireCleanupTest do
  use Shortnr.DataCase, async: false

  import Ecto.Query
  alias Shortnr.Repo
  alias Shortnr.Urls.Url
  alias Shortnr.Workers.ExpireCleanup

  @now DateTime.utc_now()

  defp insert_url!(slug, long_url, _expires_at) do
    %Url{}
    |> Url.changeset(%{
      shortened_url: slug,
      long_url: long_url,
      expires_at: DateTime.add(@now, 3600, :second)
    })
    |> Repo.insert!()
  end

  defp insert_event!(slug, ua \\ "UA", ip \\ "1.2.3.4") do
    Repo.insert_all("redirect_events", [
      %{shortened_url: slug, user_agent: ua, ip: ip, inserted_at: @now}
    ])
  end

  defp insert_location!(slug, lat \\ 52.1, lng \\ 21.0) do
    # Through the helper to ensure PostGIS types
    Shortnr.Metrics.Geo.insert_location!(slug, lat, lng)
  end

  test "purges analytics and url rows for expired slugs only" do
    expired_at = DateTime.add(@now, -3600, :second)
    future_at = DateTime.add(@now, 3600, :second)

    insert_url!("exp1", "https://ex.com/old", expired_at)
    insert_event!("exp1")
    insert_location!("exp1")

    insert_url!("act1", "https://ex.com/new", future_at)
    insert_event!("act1")
    insert_location!("act1")

    past_inserted = DateTime.add(@now, -7200, :second)

    Repo.update_all(
      from(u in Url, where: u.shortened_url == "exp1"),
      set: [inserted_at: past_inserted, updated_at: @now, expires_at: expired_at]
    )

    # Sanity: data present before cleanup
    assert 1 == Repo.one(from u in Url, where: u.shortened_url == "exp1", select: count())
    assert 1 == Repo.one(from u in Url, where: u.shortened_url == "act1", select: count())

    assert 1 ==
             Repo.one(
               from e in "redirect_events", where: e.shortened_url == "exp1", select: count()
             )

    assert 1 ==
             Repo.one(
               from e in "redirect_events", where: e.shortened_url == "act1", select: count()
             )

    assert 1 ==
             Repo.one(
               from l in "redirect_locations", where: l.shortened_url == "exp1", select: count()
             )

    assert 1 ==
             Repo.one(
               from l in "redirect_locations", where: l.shortened_url == "act1", select: count()
             )

    assert :ok == ExpireCleanup.perform(%Oban.Job{})

    # Expired slug fully purged
    assert 0 == Repo.one(from u in Url, where: u.shortened_url == "exp1", select: count())

    assert 0 ==
             Repo.one(
               from e in "redirect_events", where: e.shortened_url == "exp1", select: count()
             )

    assert 0 ==
             Repo.one(
               from l in "redirect_locations", where: l.shortened_url == "exp1", select: count()
             )

    # Active slug untouched
    assert 1 == Repo.one(from u in Url, where: u.shortened_url == "act1", select: count())

    assert 1 ==
             Repo.one(
               from e in "redirect_events", where: e.shortened_url == "act1", select: count()
             )

    assert 1 ==
             Repo.one(
               from l in "redirect_locations", where: l.shortened_url == "act1", select: count()
             )

    # Idempotency: second run should be no-op
    assert :ok == ExpireCleanup.perform(%Oban.Job{})
    assert 1 == Repo.one(from u in Url, where: u.shortened_url == "act1", select: count())
  end

  test "schedules a follow-up job when batch limit reached" do
    expired_at = DateTime.add(@now, -3600, :second)

    slugs = for i <- 1..500, do: "exp-#{i}"

    rows =
      for slug <- slugs do
        %{
          shortened_url: slug,
          long_url: "https://ex.com/#{slug}",
          # Insert valid, will backdate after
          expires_at: DateTime.add(@now, 3600, :second),
          inserted_at: @now,
          updated_at: @now
        }
      end

    Repo.insert_all("urls", rows)

    past_inserted = DateTime.add(@now, -7200, :second)

    Repo.update_all(
      from(u in Url, where: like(u.shortened_url, "exp-%")),
      set: [inserted_at: past_inserted, updated_at: @now, expires_at: expired_at]
    )

    before_count = Repo.one(from j in "oban_jobs", select: count(j.id)) || 0

    assert :ok == ExpireCleanup.perform(%Oban.Job{})

    after_count = Repo.one(from j in "oban_jobs", select: count(j.id)) || 0
    assert after_count == before_count + 1
  end
end
