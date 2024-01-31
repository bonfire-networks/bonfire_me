defmodule Bonfire.Me.Integration do
  alias Bonfire.Common.Config
  alias Bonfire.Common.Utils
  # alias Bonfire.Common.Extend
  # alias Bonfire.Common.Enums
  import Untangle

  def repo, do: Config.repo()

  def mailer, do: Config.get!(:mailer_module)

  def is_local?(thing, opts \\ []) do
    if Bonfire.Common.Extend.module_enabled?(Bonfire.Federate.ActivityPub.AdapterUtils) do
      Bonfire.Federate.ActivityPub.AdapterUtils.is_local?(thing, opts)
    end
  end

  # def maybe_search(tag_search, facets \\ nil) do
  #   # debug(searched: tag_search)
  #   # debug(facets: facets)

  #   # use search index if available
  #   if Extend.module_enabled?(Bonfire.Search) do
  #     debug("searching #{inspect(tag_search)} with facets #{inspect(facets)}")

  #     # search = Bonfire.Search.search(tag_search, opts, false, facets) |> e("hits")
  #     search =
  #       Bonfire.Search.search_by_type(tag_search, facets)
  #       |> debug("results")

  #     if(is_list(search) and search != []) do
  #       # search["hits"]
  #       search
  #       # |> Enum.map(&tag_hit_prepare(&1, tag_search))
  #       |> Enums.filter_empty([])

  #       # |> debug("maybe_search results")
  #     end
  #   end
  # end

  def maybe_index({:ok, object}), do: {:ok, maybe_index(object)}

  def maybe_index(object) do
    if Bonfire.Common.Extend.module_enabled?(
         Bonfire.Search.Indexer,
         Utils.e(object, :creator, :id, nil) ||
           Utils.e(object, :created, :creator_id, nil) || object
       ) do
      debug("search: index #{inspect(object)}")
      Bonfire.Search.Indexer.maybe_index_object(object)
      object
    else
      object
    end
  end

  def indexing_format_created(profile, character) do
    %{"creator" => indexing_format_creator(profile, character)}
  end

  def indexing_format_creator(profile, character) do
    %{
      "profile" => Bonfire.Me.Profiles.indexing_object_format(profile),
      "character" => Bonfire.Me.Characters.indexing_object_format(character)
    }
  end
end
