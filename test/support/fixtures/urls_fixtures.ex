defmodule Shortnr.UrlsFixtures do
  @moduledoc """
  Test helpers for creating URL records via the Shortnr.Urls context.
  """

  def unique_slug, do: "slug_#{System.unique_integer([:positive])}"

  def valid_url_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      long_url: "https://example.com/#{System.unique_integer([:positive])}",
      shortened_url: unique_slug(),
      redirect_count: 0
    })
  end

  def url_fixture(attrs \\ %{}) do
    {:ok, url} =
      attrs
      |> valid_url_attrs()
      |> Shortnr.Urls.create_url()

    url
  end
end
