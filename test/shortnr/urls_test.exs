defmodule Shortnr.UrlsTest do
  use Shortnr.DataCase, async: true

  alias Shortnr.Urls
  alias Shortnr.Urls.Url

  import Shortnr.UrlsFixtures

  describe "create_url/1" do
    test "creates a url with valid data" do
      attrs = %{
        long_url: "https://hex.pm/packages/phoenix",
        shortened_url: unique_slug()
      }

      assert {:ok, %Url{} = url} = Urls.create_url(attrs)
      assert url.long_url == attrs.long_url
      assert url.shortened_url == attrs.shortened_url
      assert url.redirect_count == 0
      assert url.expires_at == nil
    end

    test "returns error changeset with invalid data" do
      assert {:error, changeset} = Urls.create_url(%{})
      refute changeset.valid?
      assert %{long_url: [_ | _], shortened_url: [_ | _]} = errors_on(changeset)
    end

    test "enforces uniqueness on shortened_url (primary key)" do
      slug = unique_slug()
      {:ok, _url} = Urls.create_url(%{long_url: "https://example.com/1", shortened_url: slug})

      assert {:error, changeset} =
               Urls.create_url(%{long_url: "https://example.com/2", shortened_url: slug})

      assert %{shortened_url: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "list_urls/0" do
    test "returns urls ordered by inserted_at desc" do
      u1 = url_fixture(%{long_url: "https://example.com/a"})
      u2 = url_fixture(%{long_url: "https://example.com/b"})

      assert [first, second | _] = Urls.list_urls()
      assert first.shortened_url == u2.shortened_url
      assert second.shortened_url == u1.shortened_url
    end
  end

  describe "change_url/2" do
    test "returns a changeset for a new url" do
      changeset = Urls.change_url(%Url{})
      assert %Ecto.Changeset{} = changeset
      # required fields missing
      refute changeset.valid?
    end

    test "returns a valid changeset with attrs" do
      attrs = %{long_url: "https://example.org", shortened_url: unique_slug()}
      changeset = Urls.change_url(%Url{}, attrs)
      assert changeset.valid?
    end
  end

  describe "create_shortened_url/2" do
    test "creates a new mapping and normalizes URL" do
      input = "HTTP://Example.com:80/path#frag"
      normalized = Urls.normalize_url(input)

      assert {:ok, %Url{} = url} = Urls.create_shortened_url(%{long_url: input})
      assert url.long_url == normalized
      assert String.length(url.shortened_url) == 8
      assert url.shortened_url =~ ~r/^[0-9A-Za-z]+$/
      assert url.redirect_count == 0

      slug = url.shortened_url
      assert {:ok, ^slug} = Shortnr.UrlCache.get(normalized)
    end

    test "reuses existing mapping for equivalent normalized URL" do
      a = "http://EXAMPLE.com:80/a"
      b = "http://example.com/a#section"

      assert {:ok, %Url{} = u1} = Urls.create_shortened_url(%{long_url: a})
      assert {:ok, %Url{} = u2} = Urls.create_shortened_url(%{long_url: b})

      assert u1.shortened_url == u2.shortened_url
      assert u1.long_url == Urls.normalize_url(a)
      assert u2.long_url == Urls.normalize_url(b)
    end

    test "uses cache hit path" do
      {:ok, %Url{} = u1} = Urls.create_shortened_url(%{long_url: "https://example.com/cache"})
      # Second call should hit cache branch and return the same record
      assert {:ok, %Url{} = u2} =
               Urls.create_shortened_url(%{long_url: "https://example.com/cache"})

      assert u1.shortened_url == u2.shortened_url
    end

    test "cache hit with missing DB record falls back to insert" do
      normalized = Urls.normalize_url("https://example.com/missing")
      bogus = "B0GUS123"
      :ok = Shortnr.UrlCache.put(normalized, bogus)

      assert {:ok, %Url{} = url} = Urls.create_shortened_url(%{long_url: normalized})
      refute url.shortened_url == bogus
      assert url.long_url == normalized
    end

    test "retries on slug collision with different long_url" do
      target_long = "https://example.com/collide"
      normalized = Urls.normalize_url(target_long)
      collide_slug = Shortnr.Slug.generate(normalized, 0)

      # Preinsert a different URL using the colliding slug
      other_long = "https://other.com/x"
      {:ok, _} = Urls.create_url(%{long_url: other_long, shortened_url: collide_slug})

      # Should not return the colliding slug
      assert {:ok, %Url{} = url} = Urls.create_shortened_url(%{long_url: target_long})
      assert url.long_url == normalized
      refute url.shortened_url == collide_slug
    end

    test "db hit path when cache is empty" do
      {:ok, %Url{} = u1} = Urls.create_shortened_url(%{long_url: "https://example.com/db-only"})
      # Clear ETS to simulate cold start
      if :ets.whereis(Shortnr.UrlCache) != :undefined do
        :ets.delete_all_objects(Shortnr.UrlCache)
      end

      assert {:ok, %Url{} = u2} =
               Urls.create_shortened_url(%{long_url: "https://example.com/db-only"})

      assert u1.shortened_url == u2.shortened_url
    end
  end

  describe "lookups" do
    test "get_active_by_slug/1 and get_active_by_long_url/1 return records" do
      {:ok, %Url{} = url} = Urls.create_shortened_url(%{long_url: "https://example.org/x"})

      slug = url.shortened_url
      long = url.long_url

      assert %Url{shortened_url: ^slug} = Urls.get_active_by_slug(slug)
      assert %Url{long_url: ^long} = Urls.get_active_by_long_url(long)
    end

    test "returns nil for expired records" do
      # Insert with near-future expiry to satisfy DB constraint, then wait
      soon = DateTime.utc_now() |> DateTime.add(1, :second)
      slug = unique_slug()

      {:ok, %Url{} = url} =
        Urls.create_url(%{
          long_url: "https://ex.com/expired",
          shortened_url: slug,
          expires_at: soon
        })

      # Ensure it expires
      Process.sleep(1100)

      assert Urls.get_active_by_slug(url.shortened_url) == nil
      assert Urls.get_active_by_long_url(url.long_url) == nil
    end
  end

  describe "normalize_url/1" do
    test "lowercases host, strips default ports and fragments, ensures path" do
      assert Urls.normalize_url("http://ExAmPlE.com:80") == "http://example.com/"
      assert Urls.normalize_url("https://Example.com:443/abc#x") == "https://example.com/abc"
    end

    test "returns input when invalid" do
      assert Urls.normalize_url("notaurl") == "notaurl"
      assert Urls.normalize_url("ftp://example.com/path") == "ftp://example.com/path"
    end
  end

  describe "create_shortened_url/2 options" do
    test "exhausted attempts returns error" do
      # Force zero attempts to hit the exhausted branch immediately
      assert {:error, :exhausted_attempts} =
               Urls.create_shortened_url(%{long_url: "https://ex.com/y"}, max_attempts: 0)
    end
  end
end
