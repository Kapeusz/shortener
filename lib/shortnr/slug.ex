defmodule Shortnr.Slug do
  @moduledoc "Deterministic Base62 slugs via HMAC-SHA256."

  @alphabet ~c(0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz)
  @base 62
  @default_len 8

  @doc "Generate a slug; retries add a small salt."
  def generate(url, attempt \\ 0, len \\ @default_len)
      when is_binary(url) and is_integer(attempt) do
    secret =
      System.get_env("SLUG_SECRET") ||
        Application.get_env(:shortnr, :slug_secret) ||
        "dev-secret"

    data = if attempt == 0, do: url, else: url <> ":" <> salt()

    # Use first `len` HMAC bytes and map to Base62
    mac = :crypto.mac(:hmac, :sha256, secret, data)
    prefix = binary_part(mac, 0, min(byte_size(mac), len))
    prefix |> :binary.decode_unsigned(:big) |> to_base62(len)
  end

  defp to_base62(int, len) when is_integer(int) and int >= 0 do
    chars = do_base62(int, []) |> List.to_string()

    if byte_size(chars) >= len do
      binary_part(chars, 0, len)
    else
      String.pad_leading(chars, len, "0")
    end
  end

  defp do_base62(0, []), do: ~c"0"
  defp do_base62(0, acc), do: acc

  defp do_base62(n, acc) do
    do_base62(div(n, @base), [Enum.at(@alphabet, rem(n, @base)) | acc])
  end

  defp salt do
    Base.encode16(:crypto.strong_rand_bytes(2), case: :lower)
  end
end
