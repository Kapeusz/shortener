defmodule Shortnr.Urls.UrlParamTest do
  use ExUnit.Case, async: true

  alias Shortnr.Urls.Url

  test "Phoenix.Param for Url returns shortened_url" do
    u = %Url{shortened_url: "abcd", long_url: "https://example.com"}
    assert Phoenix.Param.to_param(u) == "abcd"
  end
end
