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
end
