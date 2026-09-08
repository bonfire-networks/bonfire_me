defmodule Bonfire.Me.SensitiveActions.DeleteUser do
  @moduledoc "Profile deletion by its owning account after sudo verification."
  @behaviour Bonfire.Me.SensitiveActions.Action
  use Bonfire.Common.Localise
  alias Bonfire.Me.Users

  @impl true
  def describe(context) do
    %{
      title: l("Delete your profile"),
      description: describe_target(context),
      success: %{title: l("Profile deletion requested"), description: l("Your profile and its data have been queued for deletion.")}
    }
  end

  defp describe_target(%{account: %{id: account_id}, target_id: target_id}) when is_binary(target_id) do
    case Users.get_owned_by_account(target_id, account_id) do
      %Bonfire.Data.Identity.User{} = user ->
        l("This deletes %{profile} and its data, but keeps your account and other profiles. This action cannot be undone.",
          profile: Bonfire.Me.Characters.display_username(user, true, true))

      _ -> l("This profile is not available for deletion by your account.")
    end
  end

  defp describe_target(_),
    do: l("This deletes the selected profile and its data, but keeps your account and other profiles. This action cannot be undone.")

  @impl true
  def execute(%{account: %{id: account_id}, target_id: target_id}) do
    case Users.get_owned_by_account(target_id, account_id) do
      %Bonfire.Data.Identity.User{} = user -> Users.enqueue_delete(user)
      _ -> {:error, :not_allowed}
    end
  end

  def execute(_), do: {:error, :not_allowed}

  @impl true
  def factors, do: :any
end
