defmodule Bonfire.Me.Test.FakeHelpers do

  alias CommonsPub.Accounts.Account
  alias Bonfire.Me.Fake
  alias Bonfire.Me.{Accounts, Users}
  import ExUnit.Assertions

  @repo Application.get_env(:bonfire_me, :repo_module)

  def fake_account!(attrs \\ %{}) do
    cs = Accounts.signup_changeset(Fake.account(attrs))
    assert {:ok, account} = @repo.insert(cs)
    account
  end

  def fake_user!(%Account{}=account, attrs \\ %{}) do
    assert {:ok, user} = Users.create(Fake.user(attrs), account)
    user
  end

end
