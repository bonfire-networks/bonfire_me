defmodule Bonfire.Me.LoginEmailProviderTest do
  use Bonfire.Me.DataCase, async: true

  alias Bonfire.Me.LoginEmailProvider

  # Mock providers must be defined at module level so they are compiled and
  # their @behaviour attributes are visible before any test runs.

  defmodule OkProvider do
    @behaviour Bonfire.Me.LoginEmailProvider
    @impl true
    def ensure_account(_email), do: {:ok, :from_ok_provider}
  end

  defmodule NoMatchProvider do
    @behaviour Bonfire.Me.LoginEmailProvider
    @impl true
    def ensure_account(_email), do: :no_match
  end

  defmodule ErrorProvider do
    @behaviour Bonfire.Me.LoginEmailProvider
    @impl true
    def ensure_account(_email), do: {:error, :upstream_down}
  end

  defmodule RaisingProvider do
    @behaviour Bonfire.Me.LoginEmailProvider
    @impl true
    def ensure_account(_email), do: raise("boom")
  end

  defmodule ThrowingProvider do
    @behaviour Bonfire.Me.LoginEmailProvider
    @impl true
    def ensure_account(_email), do: throw(:boom)
  end

  defmodule ReconcileProvider do
    @behaviour Bonfire.Me.LoginEmailProvider
    @impl true
    def ensure_account(_email), do: :no_match
    @impl true
    def reconcile_account(_email, account), do: {:ok, account}
  end

  defmodule ExitingReconcileProvider do
    @behaviour Bonfire.Me.LoginEmailProvider
    @impl true
    def ensure_account(_email), do: :no_match
    @impl true
    def reconcile_account(_email, _account), do: exit(:boom)
  end

  test "returns :no_match when no providers are given" do
    assert :no_match = LoginEmailProvider.ensure([], "someone@example.com")
  end

  test "returns :no_match for empty or non-binary emails" do
    assert :no_match = LoginEmailProvider.ensure([OkProvider], "")
    assert :no_match = LoginEmailProvider.ensure([OkProvider], nil)
  end

  test "returns the first :ok result and short-circuits" do
    assert {:ok, :from_ok_provider} =
             LoginEmailProvider.ensure([OkProvider, RaisingProvider], "someone@example.com")
  end

  test "skips :no_match providers and tries the next one" do
    assert {:ok, :from_ok_provider} =
             LoginEmailProvider.ensure([NoMatchProvider, OkProvider], "someone@example.com")
  end

  test "skips error-returning providers and continues" do
    assert {:ok, :from_ok_provider} =
             LoginEmailProvider.ensure([ErrorProvider, OkProvider], "someone@example.com")
  end

  test "treats raising providers as :no_match and continues" do
    assert {:ok, :from_ok_provider} =
             LoginEmailProvider.ensure([RaisingProvider, OkProvider], "someone@example.com")
  end

  test "treats thrown provider failures as :no_match and continues" do
    assert {:ok, :from_ok_provider} =
             LoginEmailProvider.ensure([ThrowingProvider, OkProvider], "someone@example.com")
  end

  test "returns :no_match when every provider declines" do
    assert :no_match =
             LoginEmailProvider.ensure(
               [NoMatchProvider, ErrorProvider, RaisingProvider],
               "someone@example.com"
             )
  end

  test "reconcile skips providers without the optional callback and returns the first repair" do
    account = %{id: "profileless-account"}

    assert {:ok, ^account} =
             LoginEmailProvider.reconcile(
               [NoMatchProvider, ReconcileProvider],
               "someone@example.com",
               account
             )
  end

  test "reconcile returns :no_match for invalid input or when no provider implements it" do
    assert :no_match =
             LoginEmailProvider.reconcile(
               [NoMatchProvider],
               "someone@example.com",
               %{id: "profileless-account"}
             )

    assert :no_match = LoginEmailProvider.reconcile([ReconcileProvider], "", %{})
  end

  test "reconcile treats provider exits as :no_match and continues" do
    account = %{id: "profileless-account"}

    assert {:ok, ^account} =
             LoginEmailProvider.reconcile(
               [ExitingReconcileProvider, ReconcileProvider],
               "someone@example.com",
               account
             )
  end
end
