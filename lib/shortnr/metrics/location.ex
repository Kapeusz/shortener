defmodule Shortnr.Metrics.Location do
  @moduledoc "Lightweight location bucketing from IP (placeholder)."

  @spec bucket(String.t() | nil) :: String.t()
  def bucket(nil), do: "Unknown"

  def bucket(ip) when is_binary(ip) do
    cond do
      String.starts_with?(ip, ["10.", "127.", "192.168."]) -> "Private"
      ip |> String.split(".") |> private_172?() -> "Private"
      String.contains?(ip, ":") -> "IPv6"
      true -> "Public"
    end
  end

  defp private_172?(["172", second | _]) do
    case Integer.parse(second) do
      {n, _} when n >= 16 and n <= 31 -> true
      _ -> false
    end
  end

  defp private_172?(_), do: false
end
