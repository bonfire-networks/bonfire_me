defmodule Bonfire.Me.RuntimeConfigTest do
  use ExUnit.Case, async: true

  # bucket this into the backend CI leg: bare `ExUnit.Case` skips the tag the extension case templates apply, so without it this also runs in the federation job catch-all
  @moduletag :backend

  import ExUnit.CaptureLog
  alias Bonfire.Me.RuntimeConfig

  describe "email_link_grace_seconds/1 (the EMAIL_LINK_GRACE_SECONDS env var)" do
    test "unset or empty keeps the default" do
      assert RuntimeConfig.email_link_grace_seconds(nil) == nil
      assert RuntimeConfig.email_link_grace_seconds("") == nil
    end

    test "a whole number of seconds from 0 up is used, and 0 means strictly single-use" do
      assert RuntimeConfig.email_link_grace_seconds("0") == 0
      assert RuntimeConfig.email_link_grace_seconds("300") == 300
      assert RuntimeConfig.email_link_grace_seconds(" 90 ") == 90
    end

    test "anything else keeps the default, with a warning that names the variable" do
      for bad <- ["-5", "abc", "1.5", "5min"] do
        log = capture_log(fn -> assert RuntimeConfig.email_link_grace_seconds(bad) == nil end)

        assert log =~ "EMAIL_LINK_GRACE_SECONDS"
      end
    end
  end
end
