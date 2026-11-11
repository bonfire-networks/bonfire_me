defmodule Bonfire.Me.SensitiveActions.DeleteUser do
  @moduledoc """
  Profile deletion after sudo verification, by either of:

  - the account that owns the profile (a caretaker of a shared profile doesn't qualify)
  - an instance admin, for any local or remote user who is already blocked instance-wide, so a deletion is never the first moderation step; never for a user who is an instance admin themselves, whose admin role is revoked first
  """
  @behaviour Bonfire.Me.SensitiveActions.Action
  use Bonfire.Common.Localise
  import Bonfire.Me.Integration, only: [repo: 0]
  alias Bonfire.Me.Users

  @impl true
  def describe(context) do
    target = resolve_target(context)

    %{
      title: describe_title(target),
      description: describe_target(target),
      success: %{
        title: l("Profile deletion requested"),
        description: l("Your profile and its data have been queued for deletion.")
      }
    }
  end

  defp describe_title({:admin, _}), do: l("Delete this user")
  defp describe_title({:admin_unblocked, _}), do: l("Delete this user")
  defp describe_title({:target_admin, _}), do: l("Delete this user")
  defp describe_title(_), do: l("Delete your profile")

  defp describe_target({:owner, user}) do
    l(
      "This deletes %{profile} and its data, but keeps your account and other profiles. This action cannot be undone.",
      profile: Bonfire.Me.Characters.display_username(user, true, true)
    )
  end

  defp describe_target({:admin, user}) do
    l(
      "This deletes %{profile} and its data, but keeps their account and other profiles. This action cannot be undone.",
      profile: Bonfire.Me.Characters.display_username(user, true, true)
    )
  end

  defp describe_target({:admin_unblocked, _}),
    do: l("Block this user instance-wide before deleting them.")

  defp describe_target({:target_admin, _}),
    do: l("This user is an instance admin, so revoke their admin role first, then delete them.")

  defp describe_target(:none) do
    l("This profile is not available for deletion by your account.")
  end

  defp describe_target(:unspecified),
    do:
      l(
        "This deletes the selected profile and its data, but keeps your account and other profiles. This action cannot be undone."
      )

  @impl true
  def execute(context) do
    case resolve_target(context) do
      {kind, %Bonfire.Data.Identity.User{} = user} when kind in [:owner, :admin] ->
        Users.enqueue_delete(user)

      _ ->
        {:error, :not_allowed}
    end
  end

  @impl true
  def factors, do: :any

  # the target, with the reason this account may act on it: `:owner`, `:admin` (blocked instance-wide), `:admin_unblocked` (an admin, but the user isn't blocked yet), or `:none`
  defp resolve_target(%{account: %{id: account_id} = account, target_id: target_id})
       when is_binary(target_id) do
    case Users.get_owned_by_account(target_id, account_id) do
      %Bonfire.Data.Identity.User{} = user -> {:owner, user}
      _ -> resolve_admin_target(account, target_id)
    end
  end

  defp resolve_target(_), do: :unspecified

  @doc "The user with `:admin` when the account is an instance admin and the user (local or remote) is blocked instance-wide, with `:admin_unblocked` when only the block is missing, with `:target_admin` when the user is an instance admin themselves (their role is revoked before they can be deleted, however blocked they are), else `:none`. Shared with the account-level action."
  def resolve_admin_target(account, target_id) do
    with true <- admin?(account),
         %Bonfire.Data.Identity.User{} = user <- Users.get_current(target_id) do
      cond do
        Bonfire.Me.Accounts.admin_account_of?(user) -> {:target_admin, user}
        Bonfire.Boundaries.Blocks.is_blocked?(user, :ghost, :instance_wide) -> {:admin, user}
        true -> {:admin_unblocked, user}
      end
    else
      _ -> :none
    end
  end

  # reloaded rather than trusted, since the account may arrive with the flag unloaded or stale, and this gates a deletion (one query)
  defp admin?(account),
    do:
      Bonfire.Me.Accounts.is_admin?(%{
        account: repo().preload(account, :instance_admin, force: true)
      }) == true
end
