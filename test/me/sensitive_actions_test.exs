defmodule Bonfire.Me.SensitiveActionsTest do
  @moduledoc """
  Factor-based sudo domain logic: action resolution by Behaviour adoption, requirement resolution to the top-n available factors, per-factor freshness, and challenge selection.
  """
  use Bonfire.Me.DataCase, async: false
  import Bonfire.Me.Fake
  import Ecto.Query
  alias Bonfire.Me.SensitiveActions
  alias Bonfire.Me.SensitiveActions.DeleteAccount
  alias Bonfire.Data.Identity.Credential
  alias Bonfire.Common.Config
  doctest Bonfire.Me.SensitiveActions

  defp passwordless_account! do
    account = fake_account!()
    Bonfire.Common.Repo.delete_all(from(c in Credential, where: c.id == ^account.id))
    # reload so the deleted credential is not still sitting preloaded on the struct
    account = Bonfire.Common.Repo.get!(Bonfire.Data.Identity.Account, account.id)
    # the precondition the degrade tests rely on
    refute Bonfire.Me.Accounts.account_has_password?(account)
    account
  end

  defp put_config(key_path, value) do
    orig = Config.get(key_path)
    Config.put(key_path, value)
    on_exit(fn -> Config.put(key_path, orig) end)
  end

  describe "resolve/1" do
    test "rejects an unknown module name" do
      assert {:error, :unknown_action} = SensitiveActions.resolve("Not.A.Real.Module")
    end

    test "rejects an existing module that does not adopt the Action behaviour" do
      assert {:error, :unknown_action} = SensitiveActions.resolve("Elixir.Bonfire.Me.Accounts")
    end

    test "resolves an Action adopter by module name (positive control)" do
      assert {:ok, DeleteAccount} =
               SensitiveActions.resolve("Elixir.Bonfire.Me.SensitiveActions.DeleteAccount")
    end

    test "rejects the old registry key" do
      assert {:error, :unknown_action} = SensitiveActions.resolve("delete_account")
    end
  end

  describe "available_factors/1" do
    test "a password account has password and email, in strength order" do
      assert SensitiveActions.available_factors(fake_account!()) == [:password, :email]
    end

    test "a passwordless account has only email" do
      assert SensitiveActions.available_factors(passwordless_account!()) == [:email]
    end

    test "the strength order is the universe: [:email] config removes password entirely" do
      put_config([SensitiveActions, :factor_strength], [:email])
      assert SensitiveActions.available_factors(fake_account!()) == [:email]
    end

    test "a gated (passwordless-only) instance never offers the password factor, hash or no hash" do
      Process.put([:bonfire_ui_me, :login, :passwordless_only], true)
      assert SensitiveActions.available_factors(fake_account!()) == [:email]
    end
  end

  describe "required/2" do
    test ":any resolves to the single strongest available factor" do
      assert SensitiveActions.required(DeleteAccount, fake_account!()) == [:password]
    end

    test ":any degrades to email for a passwordless account" do
      assert SensitiveActions.required(DeleteAccount, passwordless_account!()) == [:email]
    end

    test "a per-module :sudo_factors override beats factors/0" do
      put_config([DeleteAccount, :sudo_factors], {:any, 2})
      assert SensitiveActions.required(DeleteAccount, fake_account!()) == [:password, :email]
    end

    test "{:any, 2} caps at what a passwordless account has available" do
      put_config([DeleteAccount, :sudo_factors], {:any, 2})
      assert SensitiveActions.required(DeleteAccount, passwordless_account!()) == [:email]
    end

    test ":all requires every available factor" do
      put_config([DeleteAccount, :sudo_factors], :all)
      assert SensitiveActions.required(DeleteAccount, fake_account!()) == [:password, :email]
    end

    test "an explicit list keeps only available factors, in strength order" do
      put_config([DeleteAccount, :sudo_factors], [:password, :email])
      assert SensitiveActions.required(DeleteAccount, passwordless_account!()) == [:email]
    end

    test "factor_strength [:email] makes every requirement email-only" do
      put_config([SensitiveActions, :factor_strength], [:email])
      assert SensitiveActions.required(DeleteAccount, fake_account!()) == [:email]
    end
  end

  describe "fresh?/2, stamp/2 and next_challenge/2" do
    test "nothing required is always met" do
      assert SensitiveActions.fresh?(%{}, []) == true
    end

    test "an empty factors map meets nothing" do
      assert SensitiveActions.fresh?(%{}, [:password]) == false
    end

    test "a stamped factor is fresh" do
      factors = SensitiveActions.stamp(%{}, :password)
      assert SensitiveActions.fresh?(factors, [:password]) == true
    end

    test "a stale factor is not fresh" do
      stale = System.system_time(:millisecond) - to_timeout(hour: 1)
      assert SensitiveActions.fresh?(%{password: stale}, [:password]) == false
    end

    test "a future timestamp fails closed" do
      future = System.system_time(:millisecond) + to_timeout(hour: 1)
      assert SensitiveActions.fresh?(%{password: future}, [:password]) == false
    end

    test "a fresh weaker factor does not substitute for the required one" do
      factors = SensitiveActions.stamp(%{}, :email)
      assert SensitiveActions.fresh?(factors, [:password]) == false
    end

    test "stamp merges without clobbering other factors" do
      factors = SensitiveActions.stamp(%{email: 123}, :password)
      assert factors[:email] == 123
      assert is_integer(factors[:password])
    end

    test "next_challenge picks the strongest required factor not yet fresh" do
      now = System.system_time(:millisecond)
      assert SensitiveActions.next_challenge(%{}, [:password, :email]) == :password
      assert SensitiveActions.next_challenge(%{password: now}, [:password, :email]) == :email

      assert SensitiveActions.next_challenge(%{password: now, email: now}, [:password, :email]) ==
               :met
    end
  end
end
