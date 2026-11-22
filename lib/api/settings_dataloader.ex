if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.Me.API.SettingsDataloader do
    @moduledoc """
    `Dataloader.KV` source: each user's `Bonfire.Data.Identity.Settings` row (its id is the user's),
    batched per GraphQL request, so a field that reads a user setting (`discoverable`) costs one
    query per page instead of one per user. Mirrors `Bonfire.Me.API.FollowCountsDataloader`.
    """

    import Ecto.Query
    use Bonfire.Common.Repo

    def data, do: Dataloader.KV.new(&fetch/2)

    @doc "Batch fetch: each user id to its `%Settings{}`, or nil when the user has none stored."
    def fetch(:settings, ids) do
      ids = MapSet.to_list(ids)

      by_id =
        from(s in Bonfire.Data.Identity.Settings, where: s.id in ^ids)
        |> repo().all()
        |> Map.new(&{&1.id, &1})

      Map.new(ids, &{&1, Map.get(by_id, &1)})
    end

    def fetch(_batch, ids), do: Map.new(MapSet.to_list(ids), &{&1, nil})
  end
end
