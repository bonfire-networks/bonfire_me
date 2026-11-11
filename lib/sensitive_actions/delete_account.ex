defmodule Bonfire.Me.SensitiveActions.DeleteAccount do
  @moduledoc """
  Account deletion after explicit, recently verified confirmation, by either of:

  - the account itself (no `target_id`)
  - an instance admin, for the account of a `target_id` profile that is blocked instance-wide: the account's other profiles go with it, blocked or not; never when the account is an instance admin's, whose admin role is revoked first
  """
  @behaviour Bonfire.Me.SensitiveActions.Action
  use Bonfire.Common.Localise
  import Bonfire.Me.Integration, only: [repo: 0]
  alias Bonfire.Me.SensitiveActions.DeleteUser

  @impl true
  def describe(context) do
    resolved = resolve_account(context)

    %{
      title: describe_title(resolved),
      description: describe_account(resolved),
      success: %{
        title: l("Account deletion requested"),
        description: l("Your account and its data have been queued for deletion.")
      }
    }
  end

  defp describe_title({:admin, _}), do: l("Delete this account")
  defp describe_title(:target_admin), do: l("Delete this account")
  defp describe_title(_), do: l("Delete your account")

  # a single COUNT of the same set `Accounts.enqueue_delete/1` deletes, never loading the profiles
  defp describe_account({:owner, account}) do
    count = count_profiles(account)

    lp(
      "This deletes your account and its %{count} profile, with their posts and other data, from this server. This action cannot be undone.",
      "This deletes your account and its %{count} profiles, with their posts and other data, from this server. This action cannot be undone.",
      count,
      count: count
    )
  end

  defp describe_account({:admin, account}) do
    count = count_profiles(account)

    lp(
      "This deletes the account and its %{count} profile, with their posts and other data, from this server. This action cannot be undone.",
      "This deletes the account and its %{count} profiles, with their posts and other data, from this server. This action cannot be undone.",
      count,
      count: count
    )
  end

  defp describe_account(:target_admin),
    do:
      l(
        "This account has an instance admin, so revoke their admin role first, then delete the account."
      )

  defp describe_account(:none),
    do: l("This account is not available for deletion by your account.")

  defp describe_account(:unspecified),
    do:
      l(
        "This deletes all your profiles, posts and other data from this server. This action cannot be undone."
      )

  defp count_profiles(account), do: repo().aggregate(Ecto.assoc(account, :users), :count)

  @impl true
  # def execute(%{account: account}), do: Bonfire.Me.DeleteWorker.enqueue_delete(account)
  # the account's profiles are queued with it, so each is deleted (and its deletion federated) as a user, and the job fails if any of them survives
  def execute(context) do
    case resolve_account(context) do
      {kind, account} when kind in [:owner, :admin] -> Bonfire.Me.Accounts.enqueue_delete(account)
      _ -> {:error, :not_allowed}
    end
  end

  # the account to delete: the caller's own without a `target_id`, else the target's, which only an admin may ask for
  defp resolve_account(%{account: %{id: _} = account, target_id: target_id})
       when is_binary(target_id) do
    with {:admin, user} <- DeleteUser.resolve_admin_target(account, target_id),
         {%{id: _} = target_account, _} <- Bonfire.Me.Accounts.by_id_or_username(user.id) do
      {:admin, target_account}
    else
      # the flag is on the account, so one admin profile makes the whole account one
      {:target_admin, _} -> :target_admin
      _ -> :none
    end
  end

  defp resolve_account(%{account: %{id: _} = account}), do: {:owner, account}
  defp resolve_account(_), do: :unspecified

  @impl true
  def factors, do: :any
end
