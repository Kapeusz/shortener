defmodule Shortnr.SlugTest do
  use ExUnit.Case, async: true

  test "deterministic for same input" do
    s1 = Shortnr.Slug.generate("https://example.com/a")
    s2 = Shortnr.Slug.generate("https://example.com/a")
    assert s1 == s2
  end

  test "respects length and alphabet" do
    s = Shortnr.Slug.generate("https://example.com/a")
    assert String.length(s) == 8
    assert s =~ ~r/^[0-9A-Za-z]+$/
  end

  test "supports custom length" do
    s4 = Shortnr.Slug.generate("https://example.com/a", 0, 4)
    s12 = Shortnr.Slug.generate("https://example.com/a", 0, 12)
    assert String.length(s4) == 4
    assert String.length(s12) == 12
    assert s4 =~ ~r/^[0-9A-Za-z]+$/
    assert s12 =~ ~r/^[0-9A-Za-z]+$/
  end

  test "env var secret overrides app env" do
    # With app env
    s_app = Shortnr.Slug.generate("https://example.com/secret")

    # Set env var and expect a different slug
    System.put_env("SLUG_SECRET", "env-secret")
    on_exit(fn -> System.delete_env("SLUG_SECRET") end)

    s_env = Shortnr.Slug.generate("https://example.com/secret")
    refute s_app == s_env
  end

  test "falls back to default secret when none set" do
    # Clear both env and app config
    prev_env = System.get_env("SLUG_SECRET")
    prev_app = Application.get_env(:shortnr, :slug_secret)

    System.delete_env("SLUG_SECRET")
    if prev_app, do: Application.delete_env(:shortnr, :slug_secret)

    on_exit(fn ->
      if prev_env, do: System.put_env("SLUG_SECRET", prev_env)
      if prev_app, do: Application.put_env(:shortnr, :slug_secret, prev_app)
    end)

    s1 = Shortnr.Slug.generate("https://example.com/default")
    s2 = Shortnr.Slug.generate("https://example.com/default")
    assert s1 == s2
    assert String.length(s1) == 8
  end

  test "attempt > 0 usually changes slug" do
    s0 = Shortnr.Slug.generate("https://example.com/a", 0)
    s1 = Shortnr.Slug.generate("https://example.com/a", 1)
    refute s0 == s1
  end
end
