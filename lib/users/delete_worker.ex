defmodule Bonfire.Me.DeleteWorker do
  use Oban.Worker,
    queue: :deletion,
    max_attempts: 3

  # import Bonfire.Me.Integration
  alias Bonfire.Common.Utils
  alias Bonfire.Common.Enums
  alias Bonfire.Common.Types
  # alias Needle.Pointer
  use Bonfire.Common.Repo

  def delete(ids, opts) do
    enqueue_delete(Bonfire.Boundaries.load_pointers(ids, opts))
  end

  def enqueue_delete(ids) do
    enqueue([queue: :deletion], %{"ids" => Types.ulids(ids)})
  end

  defp enqueue(spec, worker_args \\ []), do: Oban.insert(job(spec, worker_args))

  defp job(spec, worker_args \\ []), do: new(worker_args, spec)

  def perform(%{args: %{"ids" => ids}}) do
    delete_now(ids)
  end

  def delete_now(ids) do
    main =
      Bonfire.Boundaries.load_pointers(ids, skip_boundary_check: true, include_deleted: true)
      |> debug("main")

    Bonfire.Social.Objects.do_delete(main, federate_inline: true)
  end
end
