defmodule Bonfire.Me.DeleteWorker do
  @moduledoc "Handles queued deletion of a user and its data."

  use Oban.Worker,
    queue: :deletion,
    max_attempts: 3

  # import Bonfire.Me.Integration
  # alias Bonfire.Common.Utils
  # alias Bonfire.Common.Enums
  alias Bonfire.Common.Types
  # alias Needle.Pointer
  use Bonfire.Common.Repo

  def delete(ids, opts) do
    enqueue_delete(Bonfire.Boundaries.load_pointers(ids, opts))
  end

  def enqueue_delete(ids) do
    enqueue([queue: :deletion], %{"ids" => Types.uids(ids)})
  end

  defp enqueue(spec, worker_args \\ []),
    do: Bonfire.Common.TestInstanceRepo.oban_insert(job(spec, worker_args))

  defp job(spec, worker_args \\ []), do: new(worker_args, spec)

  def perform(%{args: %{"ids" => ids}}) do
    delete_now(ids)
  end

  def delete_now(ids, opts \\ [skip_boundary_check: true]) do
    Bonfire.Boundaries.load_pointers(ids, opts ++ [include_deleted: true])
    |> debug("main")
    |> delete_structs_now(opts)
    |> verify_deleted(ids)
  end

  # opts are threaded on rather than being applied only to the load above: whatever authorisation the caller established has to reach the nested deletes too, or a boundarised preload mid-sweep silently returns nothing and those objects are never deleted
  def delete_structs_now(structs, opts \\ [skip_boundary_check: true]) do
    Bonfire.Common.Utils.maybe_apply(
      Bonfire.Social.Objects,
      :do_delete,
      [structs, opts ++ [federate_inline: true]],
      fallback_return: {:error, "Missing required module: Bonfire.Social.Objects"}
    )
  end

  # A deletion that didn't actually delete must not report success: the caller has no other signal,
  # and downstream a `Delete` would be federated for something still present locally (or, worse,
  # not federated at all while the caller believes it was). Verified by reloading rather than
  # trusting the return value, since the sweep can partially fail without erroring.
  defp verify_deleted(result, ids) do
    case Bonfire.Boundaries.load_pointers(ids, skip_boundary_check: true, include_deleted: false) do
      [] ->
        result

      survivors ->
        error(
          Types.uids(survivors),
          "Deletion did not complete: these objects still exist afterwards"
        )
    end
  end
end
