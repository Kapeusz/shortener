defmodule Shortnr.Urls do
  @moduledoc """
  Context for managing shortened URLs.
  """
  import Ecto.Query, warn: false
  alias Shortnr.Repo

  alias Shortnr.Urls.Url
  alias Shortnr.{Slug, UrlCache}

  def list_urls do
    Repo.all(from u in Url, order_by: [desc: u.inserted_at, desc: u.shortened_url])
  end

  @doc """
  Paginate URLs ordered by newest first
  """
  def paginate_urls(page \\ 1, per_page \\ 10) when is_integer(page) and is_integer(per_page) do
    per_page = per_page |> max(1) |> min(100)
    query = from u in Url, order_by: [desc: u.inserted_at, desc: u.shortened_url]
    Repo.paginate(query, page: page, page_size: per_page)
  end

  def change_url(%Url{} = url, attrs \\ %{}) do
    Url.changeset(url, attrs)
  end

  def create_url(attrs) do
    %Url{}
    |> Url.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Create a short URL from a long URL (normalize, cache, retry on collisions)."
  def create_shortened_url(%{long_url: long_url} = attrs, opts \\ []) when is_binary(long_url) do
    normalized = normalize_url(long_url)

    with :miss <- UrlCache.get(normalized),
         nil <- get_active_by_long_url(normalized) do
      max_attempts = Keyword.get(opts, :max_attempts, 5)
      do_create_shortened_url(Map.put(attrs, :long_url, normalized), normalized, 0, max_attempts)
    else
      {:ok, slug} ->
        case get_active_by_slug(slug) do
          %Url{} = url ->
            {:ok, url}

          nil ->
            max_attempts = Keyword.get(opts, :max_attempts, 5)

            do_create_shortened_url(
              Map.put(attrs, :long_url, normalized),
              normalized,
              0,
              max_attempts
            )
        end

      %Url{} = url ->
        {:ok, url}
    end
  end

  defp do_create_shortened_url(attrs, normalized, attempt, max_attempts)
       when attempt < max_attempts do
    slug = Slug.generate(normalized, attempt)
    params = Map.put(attrs, :shortened_url, slug)

    case create_url(params) do
      {:ok, %Url{} = url} ->
        UrlCache.put(normalized, url.shortened_url)
        {:ok, url}

      {:error, %Ecto.Changeset{} = changeset} = err ->
        case Keyword.get(changeset.errors, :shortened_url) do
          {"has already been taken", _} ->
            case get_active_by_slug(slug) do
              %Url{long_url: ^normalized} = existing -> {:ok, existing}
              _ -> do_create_shortened_url(attrs, normalized, attempt + 1, max_attempts)
            end

          _ ->
            err
        end
    end
  end

  defp do_create_shortened_url(_attrs, _normalized, _attempt, _max_attempts),
    do: {:error, :exhausted_attempts}

  @doc "Get active URL by slug or nil."
  def get_active_by_slug(slug) when is_binary(slug) do
    now = DateTime.utc_now()

    Repo.one(
      from u in Url,
        where: u.shortened_url == ^slug and u.expires_at > ^now,
        limit: 1
    )
  end

  @doc "Get active URL by normalized long_url or nil."
  def get_active_by_long_url(long_url) when is_binary(long_url) do
    normalized = normalize_url(long_url)
    now = DateTime.utc_now()

    Repo.one(
      from u in Url,
        where: u.long_url == ^normalized and u.expires_at > ^now,
        limit: 1
    )
  end

  @doc "Normalize for dedupe: lowercase host, strip default ports/fragments, ensure '/' path."
  def normalize_url(url) when is_binary(url) do
    uri = URI.parse(url)

    cond do
      is_nil(uri.scheme) or uri.scheme not in ["http", "https"] ->
        url

      is_nil(uri.host) or uri.host == "" ->
        url

      true ->
        host = String.downcase(uri.host)

        port =
          case {uri.scheme, uri.port} do
            {"http", 80} -> nil
            {"https", 443} -> nil
            {_, p} -> p
          end

        path =
          case uri.path do
            nil -> "/"
            "" -> "/"
            p -> p
          end

        uri = %URI{uri | host: host, port: port, path: path, fragment: nil}
        URI.to_string(uri)
    end
  end
end
