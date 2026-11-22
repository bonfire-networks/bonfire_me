if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.Me.API.CharactersDataloader do
    @moduledoc """
    `Dataloader.KV` source: characters by id as a reader may see them (`Bonfire.Me.API.GraphQL.characters_by_ids/2`), batched per GraphQL request, so the participants and senders of a page of conversations cost one read instead of one per conversation. Mirrors `Bonfire.Poll.API.VoteStateDataloader`, whose keys also carry the reader.
    """

    def data, do: Dataloader.KV.new(&fetch/2)

    @doc "Keys are `{character_id, reader}`; one request has one reader, grouped anyway. A character the reader may not see maps to nil."
    def fetch(:character, keys) do
      keys
      |> Enum.group_by(&elem(&1, 1), &elem(&1, 0))
      |> Enum.flat_map(fn {reader, ids} ->
        by_id =
          ids
          |> Enum.uniq()
          |> Bonfire.Me.API.GraphQL.characters_by_ids(reader)
          |> Map.new(&{Bonfire.Common.Types.uid(&1), &1})

        Enum.map(ids, &{{&1, reader}, Map.get(by_id, &1)})
      end)
      |> Map.new()
    end

    def fetch(_batch, keys), do: Map.new(keys, &{&1, nil})
  end
end
