defmodule Shortnr.Metrics.UATest do
  use ExUnit.Case, async: true

  alias Shortnr.Metrics.UA

  test "browser detection covers common agents" do
    assert UA.browser(nil) == "Unknown"

    assert UA.browser(
             "Mozilla/5.0 (Windows NT) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"
           ) == "Chrome"

    assert UA.browser("Mozilla/5.0 (Macintosh; Intel Mac OS X) Firefox/118.0") == "Firefox"

    assert UA.browser("Mozilla/5.0 (Macintosh; Intel Mac OS X) Version/16.1 Safari/605.1.15") ==
             "Safari"

    assert UA.browser("Mozilla/5.0 (Windows NT) Edg/120.0") == "Edge"
    assert UA.browser("Mozilla/5.0 (Windows NT) OPR/80.0") == "Opera"
    assert UA.browser("Something Else") == "Other"
  end
end
