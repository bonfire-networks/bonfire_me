defmodule Bonfire.Me.SensitiveActions.ChangeEmail do
  @moduledoc """
  Changing the account's email address after recent verification, so a signed-in session that merely was left open or borrowed cannot swap the address (the first step of taking an account over by resetting its password). The `target_id` is the new address. The account's other sessions end once it is changed.
  """
  @behaviour Bonfire.Me.SensitiveActions.Action
  use Bonfire.Common.Localise
  import Bonfire.Me.Integration, only: [repo: 0]
  alias Bonfire.Me.Accounts

  @impl true
  def describe(context) do
    %{
      title: l("Change your email"),
      description:
        case context do
          %{target_id: new} when is_binary(new) and new != "" ->
            l("This changes your account's email address to %{email}.", email: new)

          _ ->
            l("This changes your account's email address.")
        end,
      success: %{
        title: l("Email change requested"),
        description: l("Please check your email for a confirmation link...")
      }
    }
  end

  @impl true
  # the current address is read fresh, so only this account's own address can be replaced
  def execute(%{account: %{id: _} = account, target_id: new}) when is_binary(new) do
    with %{email: %{email_address: old}} <- repo().preload(account, :email),
         {:ok, account} <-
           Accounts.change_email(account, %{"old_email" => old, "email" => new}),
         {:ok, now} <- Accounts.revoke_other_sessions(account) do
      {:ok, %{sessions_revoked_at: now}}
    else
      %{} -> {:error, :no_email}
      error -> error
    end
  end

  def execute(_), do: {:error, :not_allowed}

  @impl true
  def factors, do: :any
end
