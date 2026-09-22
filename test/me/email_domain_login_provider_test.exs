defmodule Bonfire.Me.EmailDomainLoginProviderTest do
  use Bonfire.Me.ConnCase, async: true
  alias Bonfire.Me.EmailAllowedDomainsLoginProvider
  alias Bonfire.Me.Accounts

  test "provisions an account for an unknown email on an allowed domain" do
    Process.put([:bonfire_me, Accounts, :allowed_email_domains], ["example.com"])
    email = "newbie-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, account} = EmailAllowedDomainsLoginProvider.ensure_account(email)
    assert account.email.email_address == email
    assert Accounts.get_by_email(email)
  end

  test "declines (:no_match) an email off the allowed domains" do
    Process.put([:bonfire_me, Accounts, :allowed_email_domains], ["example.com"])
    assert :no_match = EmailAllowedDomainsLoginProvider.ensure_account("someone@other.test")
  end

  test "declines (:no_match) when no domains are configured" do
    assert :no_match = EmailAllowedDomainsLoginProvider.ensure_account("someone@example.com")
  end
end
