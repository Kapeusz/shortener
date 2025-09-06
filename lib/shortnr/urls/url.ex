defmodule Shortnr.Urls.Url do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:shortened_url, :string, autogenerate: false}
  @derive {Phoenix.Param, key: :shortened_url}
  schema "urls" do
    field :long_url, :string
    field :redirect_count, :integer, default: 0
    field :expires_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec, inserted_at: :inserted_at, updated_at: :updated_at)
  end

  @shortcode_regex ~r/^[A-Za-z0-9_-]+$/

  def changeset(%__MODULE__{} = url, attrs) do
    is_new = is_nil(url.shortened_url)

    allowed =
      if is_new, do: [:shortened_url, :long_url, :expires_at], else: [:long_url, :expires_at]

    required = if is_new, do: [:shortened_url, :long_url], else: [:long_url]

    url
    |> cast(attrs, allowed)
    |> validate_required(required)
    |> validate_length(:shortened_url, min: 4, max: 32)
    |> validate_format(:shortened_url, @shortcode_regex)
    |> validate_change(:long_url, &validate_url/2)
    # Partitioned tables raise PK violations from child partitions,
    # e.g. "urls_p30_pkey". Match by prefix to capture them.
    |> unique_constraint(:shortened_url, name: "urls_p", match: :prefix)
    |> check_constraint(:shortened_url,
      name: :shortened_url_len,
      message: "must be 4–32 characters"
    )
    |> check_constraint(:shortened_url,
      name: :shortened_url_charset,
      message: "invalid characters (A–Z, a–z, 0–9, _ or -)"
    )
    |> check_constraint(:expires_at,
      name: :expires_after_insert,
      message: "must be after inserted_at"
    )
  end

  # Helper: basic URL sanity (http/https with host)
  defp validate_url(:long_url, value) when is_binary(value) do
    uri = URI.parse(value)

    cond do
      is_nil(uri.scheme) or uri.scheme not in ["http", "https"] ->
        [long_url: "must start with http or https"]

      is_nil(uri.host) or uri.host == "" ->
        [long_url: "must include a host"]

      true ->
        []
    end
  end

  defp validate_url(:long_url, _), do: [long_url: "is invalid"]
end
