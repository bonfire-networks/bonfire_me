defmodule Bonfire.Me.SensitiveActions.PruneWorker do
  @moduledoc "Removes expired verification state so abandoned email proofs are not retained indefinitely."
  use Oban.Worker, queue: :database_prune, max_attempts: 3

  @doc "Prunes expired requests through the sensitive-actions context."
  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    with {:ok, _count} <- Bonfire.Me.SensitiveActions.prune_expired() do
      :ok
    end
  end
end
