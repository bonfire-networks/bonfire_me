defmodule Bonfire.Me.Integration do
  alias Bonfire.Common.Config
  alias Bonfire.Common.Utils
  require Logger

  def repo, do: Config.get!(:repo_module)

  def mailer, do: Config.get!(:mailer_module)

  def maybe_index({:ok, object}), do: {:ok, maybe_index(object)}
  def maybe_index(object) do
    if Config.module_enabled?(Bonfire.Search.Indexer) do
      Logger.info("search: index #{inspect object}")
      Bonfire.Search.Indexer.maybe_index_object(object)
      object
    else
      object
    end
  end



end
