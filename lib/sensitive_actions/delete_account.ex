defmodule Bonfire.Me.SensitiveActions.DeleteAccount do
  @moduledoc "Account deletion after explicit, recently verified confirmation."
  @behaviour Bonfire.Me.SensitiveActions.Action
  use Bonfire.Common.Localise

  @impl true
  def describe(_context) do
    %{
      title: l("Delete your account"),
      description: l("This deletes all your profiles, posts and other data from this server. This action cannot be undone."),
      success: %{
        title: l("Account deletion requested"),
        description: l("Your account and its data have been queued for deletion.")
      }
    }
  end

  @impl true
  def authorize(%{account: %{id: id}, pending: %{account_id: id, target_id: id}}), do: :ok
  def authorize(_), do: {:error, :not_allowed}

  @impl true
  def execute(%{account: account}), do: Bonfire.Me.DeleteWorker.enqueue_delete(account)
end
