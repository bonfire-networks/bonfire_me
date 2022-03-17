defmodule Bonfire.Me.Integration do
  alias Bonfire.Common.Config
  alias Bonfire.Common.Utils
  import Where

  def repo, do: Config.get!(:repo_module)

  def mailer, do: Config.get!(:mailer_module)

  def is_local?(thing) do
    if Bonfire.Common.Extend.module_enabled?(Bonfire.Federate.ActivityPub.Utils) do
      Bonfire.Federate.ActivityPub.Utils.is_local?(thing)
    end
  end

  def maybe_index({:ok, object}), do: {:ok, maybe_index(object)}
  def maybe_index(object) do
    if Bonfire.Common.Extend.module_enabled?(Bonfire.Search.Indexer) do
      debug("search: index #{inspect object}")
      Bonfire.Search.Indexer.maybe_index_object(object)
      object
    else
      object
    end
  end

  def indexing_format(profile, character) do
    %{
        "profile" => Bonfire.Me.Profiles.indexing_object_format(profile),
        "character" => Bonfire.Me.Characters.indexing_object_format(character),
    }
  end

end
