defmodule Bonfire.Me.API.FollowCountsDataloader do
  @moduledoc """
  `Dataloader.KV` source for `followers_count` and `following_count`: accepted follows per user or
  group, batched per request (`Follows.follow_counts_many/1`). Not the `FollowCount` row, which
  counts pending requests too.
  """

  @doc "Dataloader.KV source for follow counts."
  def data, do: Dataloader.KV.new(&fetch/2)

  @doc "Batch fetch: each id to `%{object_count: followers, subject_count: following}`."
  def fetch(:counts, ids),
    do: ids |> MapSet.to_list() |> Bonfire.Social.Graph.Follows.follow_counts_many()

  def fetch(_batch, ids) do
    Map.new(MapSet.to_list(ids), &{&1, nil})
  end
end
