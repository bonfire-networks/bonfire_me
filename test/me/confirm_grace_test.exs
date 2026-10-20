defmodule Bonfire.Me.ConfirmGraceTest do
  @moduledoc "The `:confirm_grace` setting of `Bonfire.Data.Identity.Email` (set from the EMAIL_LINK_GRACE_SECONDS env var) decides how long a used emailed link keeps working. It is read from the application environment, which a test can only change for everyone, so this module doesn't run async."
  use Bonfire.Me.DataCase, async: false
  alias Bonfire.Me.Accounts

  defp put_grace(value) do
    key = Bonfire.Data.Identity.Email
    previous = Application.get_env(:bonfire_data_identity, key, [])

    Application.put_env(
      :bonfire_data_identity,
      key,
      Keyword.put(previous, :confirm_grace, value)
    )

    on_exit(fn -> Application.put_env(:bonfire_data_identity, key, previous) end)
  end

  defp unconfirmed_token do
    assert {:ok, account} = Accounts.signup(signup_form(), must_confirm?: true)
    account.email.confirm_token
  end

  test "a grace of zero makes a used link strictly single-use" do
    put_grace({0, :second})
    token = unconfirmed_token()

    assert {:ok, _} = Accounts.confirm_email(token)
    assert {:error, :already_confirmed} = Accounts.confirm_email(token)
  end

  test "a longer grace keeps a used link working for that long" do
    put_grace({1, :hour})
    token = unconfirmed_token()

    assert {:ok, account} = Accounts.confirm_email(token)
    assert DateTime.diff(account.email.confirm_until, DateTime.utc_now()) in 3500..3600
    assert {:ok, _} = Accounts.confirm_email(token)
  end
end
