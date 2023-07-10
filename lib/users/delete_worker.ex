defmodule Bonfire.Me.DeleteWorker do
  use Oban.Worker,
    queue: :deletion,
    max_attempts: 1

  # import Bonfire.Me.Integration
  alias Bonfire.Common.Utils
  alias Bonfire.Common.Enums
  alias Bonfire.Common.Types
  alias Pointers.Pointer
  alias Bonfire.Data.Identity.CareClosure
  use Bonfire.Common.Repo

  def delete(ids, opts) do
    do_delete(Bonfire.Boundaries.load_pointers(ids, opts))
  end

  def do_delete(ids) do
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

    # ^ `from: Pointer` means we include deleted ones (in case we need to sweep associated data that isn't fully deleted)

    closures =
      (closures(main) ++ main)
      |> Enums.uniq_by_id()
      |> debug(
        "First of all, we must collate a list of recursive caretakers, plus ID(s) provided"
      )

    care_taken = care_taken(ids)

    care_taken
    |> Enum.map(&(Utils.e(&1, :pointer, nil) || Utils.id(&1)))
    |> debug("then delete list things they are caretaker of ")
    |> Bonfire.Social.Objects.do_delete(skip_boundary_check: true)
    |> debug("deleted care_taken")

    Bonfire.Social.Objects.do_delete(closures, skip_boundary_check: true)
    |> debug("then delete the caretakers themselves")

    Bonfire.Ecto.Acts.Delete.maybe_delete(closures, repo())
    |> debug("double-check that main things are deleted")
  end

  def closures(ids), do: repo().all(CareClosure.by_branch(Types.ulids(ids)))

  def care_taken(ids),
    do:
      repo().all(
        from(c in Bonfire.Data.Identity.Caretaker, where: c.caretaker_id in ^Types.ulids(ids))
        |> proload(:pointer)
      )
      |> repo().maybe_preload(:pointer)
end
