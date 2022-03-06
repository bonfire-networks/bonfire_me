defmodule Bonfire.Me.DeleteWorker do

  use Oban.Worker,
    queue: :deletion,
    max_attempts: 1
  
  alias Pointers.Pointer
  alias Bonfire.Repo
  alias Bonfire.Data.Identity.CareClosure
  import EctoSparkles
  import Ecto.Query

  def job(spec, worker_args \\ []), do: new(spec, worker_args(worker_args))

  def enqueue(spec, worker_args \\ []), do: Oban.insert(job(spec, worker_args))

  defp worker_args(args) do
    Application.get_env(:bonfire_me, __MODULE__, [])
    |> Keyword.get(:retries, 1)
    |> case do
      nil -> args
      retries -> Keyword.put_new(args, :max_attempts, retries)
    end
  end

  def perform(%{args: %{"ids" => ids}}) do
    #
    # First of all, we must collate a list of everything we wish to delete and retrieve their pointers entries
    # closure = Repo.all(get_closure(ids))
  end

  def closure(ids), do: Repo.all(CareClosure.by_branch(ids))

end
