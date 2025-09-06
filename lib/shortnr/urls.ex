defmodule Shortnr.Urls do
  @moduledoc """
  Context for managing shortened URLs.
  """
  import Ecto.Query, warn: false
  alias Shortnr.Repo

  alias Shortnr.Urls.Url

  def list_urls do
    Repo.all(from u in Url, order_by: [desc: u.inserted_at, desc: u.shortened_url])
  end

  def change_url(%Url{} = url, attrs \\ %{}) do
    Url.changeset(url, attrs)
  end

  def create_url(attrs) do
    %Url{}
    |> Url.changeset(attrs)
    |> Repo.insert()
  end
end
