defmodule Shortnr.Metrics.UA do
  @moduledoc "Basic browser detection from User-Agent."

  @spec browser(String.t() | nil) :: String.t()
  def browser(nil), do: "Unknown"

  def browser(ua) when is_binary(ua) do
    cond do
      String.contains?(ua, ["Edg/", "Edge/"]) ->
        "Edge"

      String.contains?(ua, "Chrome/") and not String.contains?(ua, "Chromium") ->
        "Chrome"

      String.contains?(ua, "Firefox/") ->
        "Firefox"

      String.contains?(ua, ["Safari/", "Version/"]) and not String.contains?(ua, "Chrome/") ->
        "Safari"

      String.contains?(ua, ["OPR/", "Opera"]) ->
        "Opera"

      true ->
        "Other"
    end
  end
end
