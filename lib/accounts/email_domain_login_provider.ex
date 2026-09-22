defmodule Bonfire.Me.EmailAllowedDomainsLoginProvider do
  @moduledoc """
  Implements `Bonfire.Me.LoginEmailProvider` so that anyone whose email is on the instance's
  allowed-domain list can sign up by magic link.

  When an unknown allowed-domain email is entered on the passwordless login form, this provisions a passwordless local account (see `Bonfire.Me.Accounts.allowed_email_domains/0`, set via `SIGNUP_ALLOWED_EMAIL_DOMAINS`) and the standard magic-link flow sends the sign-in link. Off-list emails are declined with `:no_match`, so the flow stays neutral and never reveals whether an account exists. This is a thin adapter; the gate and provisioning live in `Bonfire.Me.Accounts`.
  """
  @behaviour Bonfire.Me.LoginEmailProvider

  alias Bonfire.Me.Accounts

  @impl true
  def ensure_account(email) when is_binary(email) and email != "" do
    if Accounts.email_on_allowed_domain?(email) do
      Accounts.provision_passwordless_account(email)
    else
      :no_match
    end
  end

  def ensure_account(_), do: :no_match
end
