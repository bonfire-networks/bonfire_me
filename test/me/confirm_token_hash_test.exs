defmodule Bonfire.Me.ConfirmTokenHashTest do
  @moduledoc "The emailed confirm/login token is never stored as is, so a read of the table (backup, SQL injection, replica) doesn't yield working links; the emailed link still works."
  use Bonfire.Me.DataCase, async: true
  @moduletag :backend

  import Ecto.Query
  alias Bonfire.Me.Accounts

  defp stored_tokens(account_id) do
    Bonfire.Common.Repo.all(
      from(e in Bonfire.Data.Identity.Email,
        where: e.id == ^account_id,
        select: e.confirm_token
      )
    )
  end

  test "the stored value is not the emailed token, and the emailed link still works" do
    assert {:ok, account} = Accounts.signup(signup_form(), must_confirm?: true)

    emailed = account.email.confirm_token
    assert is_binary(emailed)

    assert [stored] = stored_tokens(account.id)
    assert is_binary(stored)
    refute stored == emailed

    assert :ok = Accounts.check_confirm_token(emailed)
    assert {:ok, confirmed} = Accounts.confirm_email(emailed)
    assert confirmed.id == account.id
  end

  test "the stored value does not work as a link" do
    assert {:ok, account} = Accounts.signup(signup_form(), must_confirm?: true)
    assert [stored] = stored_tokens(account.id)

    assert {:error, :not_found} = Accounts.check_confirm_token(stored)
    assert {:error, _} = Accounts.confirm_email(stored)
  end
end
