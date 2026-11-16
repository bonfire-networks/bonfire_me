defmodule Bonfire.Me.SignupPasswordLoggingTest do
  @moduledoc "Signing up never writes the plaintext password to the logs, not even with the log level at debug."
  use Bonfire.Me.DataCase, async: false
  @moduletag :backend

  import ExUnit.CaptureLog
  alias Bonfire.Me.Accounts

  setup do
    previous = Logger.level()
    Logger.configure(level: :debug)
    on_exit(fn -> Logger.configure(level: previous) end)
    :ok
  end

  test "signup succeeds and logs, but the log holds no plaintext password" do
    password = "Pw-#{System.unique_integer([:positive])}-plaintext-canary"
    form = signup_form(%{credential: %{password: password}})

    log =
      capture_log([level: :debug], fn ->
        assert {:ok, %{id: _}} = Accounts.signup(form, must_confirm?: true)
      end)

    # control: the capture works and the signup was logged
    assert log =~ "signup opts"

    refute log =~ password
  end
end
