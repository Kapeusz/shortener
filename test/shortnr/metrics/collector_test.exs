defmodule Shortnr.Metrics.CollectorTest do
  use Shortnr.DataCase, async: false

  import Ecto.Query
  alias Shortnr.{Repo}
  alias Shortnr.Urls
  alias Shortnr.Urls.Url
  alias Shortnr.Metrics.RedirectEvent

  test "flush writes events and bumps counts" do
    slug = "evt12345"
    long = "https://example.com/evt"
    {:ok, %Url{}} = Urls.create_url(%{long_url: long, shortened_url: slug})

    # Publish a few redirect events
    now = DateTime.utc_now()

    for _ <- 1..3 do
      Phoenix.PubSub.broadcast(
        Shortnr.PubSub,
        "redirects",
        {:redirect, %{slug: slug, user_agent: "UA", ip: "127.0.0.1", at: now}}
      )
    end

    # Force flush immediately
    send(Shortnr.Metrics.Collector, :flush)
    Process.sleep(50)

    # Events inserted
    count =
      Repo.aggregate(
        from(e in RedirectEvent, where: e.shortened_url == ^slug),
        :count,
        :shortened_url
      )

    assert count >= 3

    # Counter bumped
    url = Repo.get!(Url, slug)
    assert url.redirect_count >= 3
  end
end
