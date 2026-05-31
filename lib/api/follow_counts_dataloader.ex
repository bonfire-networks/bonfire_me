defmodule Bonfire.Me.API.FollowCountsDataloader do
  @moduledoc """
  `Dataloader.KV` source that batch-loads `Bonfire.Data.Social.FollowCount` (a user's
  follower/following EdgeTotal) by user id.

  `follow_count` is not an Ecto association on `User`, so it can't go through the `Needle.Pointer`
  Ecto dataloader (which raises "Valid association follow_count not found"). This KV source loads
  the totals in one batched query per request, avoiding an N+1 across user lists.
  """

  alias Bonfire.Data.Social.FollowCount
  import Ecto.Query
  use Bonfire.Common.Repo

  @doc "Dataloader.KV source for follow counts."
  def data, do: Dataloader.KV.new(&fetch/2)

  @doc "Batch fetch: maps each user id to its `%FollowCount{}` (or `nil` if no totals row yet)."
  def fetch(:counts, ids) do
    ids = MapSet.to_list(ids)

    by_id =
      from(fc in FollowCount, where: fc.id in ^ids)
      |> repo().all()
      |> Map.new(&{&1.id, &1})

    Map.new(ids, fn id -> {id, Map.get(by_id, id)} end)
  end

  def fetch(_batch, ids) do
    Map.new(MapSet.to_list(ids), &{&1, nil})
  end
end
