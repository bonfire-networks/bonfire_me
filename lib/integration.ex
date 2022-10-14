defmodule Bonfire.Me.Integration do
  alias Bonfire.Common.Config
  # alias Bonfire.Common.Utils
  import Untangle

  def repo, do: Config.get!(:repo_module)

  def mailer, do: Config.get!(:mailer_module)

  def is_local?(thing) do
    if Bonfire.Common.Extend.module_enabled?(Bonfire.Federate.ActivityPub.Utils) do
      Bonfire.Federate.ActivityPub.Utils.is_local?(thing)
    end
  end

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
