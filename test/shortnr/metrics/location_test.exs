defmodule Shortnr.Metrics.LocationTest do
  use ExUnit.Case, async: true

  alias Shortnr.Metrics.Location

  test "bucket categorizes IP addresses" do
    assert Location.bucket(nil) == "Unknown"
    assert Location.bucket("127.0.0.1") == "Private"
    assert Location.bucket("10.1.2.3") == "Private"
    assert Location.bucket("172.16.0.5") == "Private"
    assert Location.bucket("172.31.255.255") == "Private"
    assert Location.bucket("172.15.0.1") == "Public"
    assert Location.bucket("192.168.1.4") == "Private"
    assert Location.bucket("1.2.3.4") == "Public"
    assert Location.bucket("2001:db8::1") == "IPv6"
  end
end
