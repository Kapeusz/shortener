defmodule Shortnr.UrlCacheTest do
  use ExUnit.Case, async: false

  setup do
    _ = Process.whereis(Shortnr.UrlCache) || Shortnr.UrlCache.start_link([])
    if :ets.whereis(Shortnr.UrlCache) != :undefined, do: :ets.delete_all_objects(Shortnr.UrlCache)
    :ok
  end

  test "miss then put/get" do
    assert :miss == Shortnr.UrlCache.get("https://e.com/a")
    assert :ok == Shortnr.UrlCache.put("https://e.com/a", "ABC12345")
    assert {:ok, "ABC12345"} == Shortnr.UrlCache.get("https://e.com/a")
  end

  test "respects TTL" do
    System.put_env("URL_CACHE_TTL_MS", "5")
    on_exit(fn -> System.delete_env("URL_CACHE_TTL_MS") end)
    assert :ok == Shortnr.UrlCache.put("k", "v")
    assert {:ok, "v"} == Shortnr.UrlCache.get("k")
    Process.sleep(10)
    assert :miss == Shortnr.UrlCache.get("k")
  end
end
