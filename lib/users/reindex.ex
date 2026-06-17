defmodule Bonfire.Me.Users.Reindex do
  @moduledoc """
  (Re)indexes all local users into the search index, in batches.

  Implements the `EctoSparkles.DataMigration` behaviour to reuse its batched (keyset by `id`),
  throttled runner — rather than hand-rolling pagination. Trigger it directly with `reindex/1`
  (optionally `origin: :local | :remote | :all`), or as part of a full search backfill via
  `Bonfire.Search.Indexer.reindex_from_db/1` (it registers as a `Bonfire.Common.ReindexModule` to be discovered by `Bonfire.Search.Indexer`).
  """
  @behaviour EctoSparkles.DataMigration
  @behaviour Bonfire.Common.ReindexModule
  alias EctoSparkles.DataMigration

  @impl Bonfire.Common.ReindexModule
  def reindex_module, do: __MODULE__

  @impl Bonfire.Common.ReindexModule
  def reindex(opts \\ []), do: DataMigration.Runner.run(__MODULE__, opts)

  # `Queries.list(origin)` selects users by origin (`:local` non-peered by default, or `:remote`/`:all`)
  # and already join-preloads `profile` + `character`, which `maybe_index_user/1` ->
  # `indexing_object_format/1` need. Its first binding is the users table, so the runner's
  # `where id > ^last_id` / `order_by id` apply correctly. `opts[:origin]` selects the scope.
  @impl DataMigration
  def base_query(opts \\ []) do
    Bonfire.Me.Users.Queries.list(opts[:origin] || :local)
  end

  @impl DataMigration
  def config do
    # `first_id` must be castable to the `User.id` type (Needle.UID), so we use the lowest
    # ULID string rather than the DataMigration default (a raw 16-byte UUID binary), which
    # Needle.UID rejects in the runner's `where id > ^first_id`.
    %DataMigration.Config{
      batch_size: 50,
      throttle_ms: 2000,
      repo: Bonfire.Common.Repo,
      first_id: "00000000000000000000000000"
    }
  end

  # Group the batch by target index (public vs closed, per each user's discoverability) and index
  # each group in one grouped, pipelined call — `Indexer.maybe_index_object/2`'s list arity maps
  # `prepare_indexable_object/1` over the group and hands the whole list to the adapter's
  # `put_documents(list, collection)` (pipelined on Sonic). Reuses `Users.search_index_for/1` so the
  # routing logic isn't duplicated from `maybe_index_user/1`.
  @impl DataMigration
  def migrate(users) do
    users
    |> Bonfire.Common.Repo.maybe_preload(:settings)
    |> Enum.group_by(&Bonfire.Me.Users.search_index_for/1)
    |> Enum.each(fn {index, group} ->
      Bonfire.Search.Indexer.maybe_index_object(group, index)
    end)
  end
end
