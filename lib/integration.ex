defmodule Bonfire.Me.Integration do
  use Bonfire.Common.Utils
  alias Bonfire.Common.Config
  # alias Bonfire.Common.Extend
  # alias Bonfire.Common.Enums
  import Untangle

  declare_extension("Users, accounts and profiles",
    icon: "carbon:user-avatar",
    emoji: "🧑🏼",
    description:
      l("Functionality for signing in, creating, editing and viewing accounts and user profiles.")
  )

  def repo, do: Config.repo()

  def mailer, do: Config.get(:mailer_module)

  def is_local?(thing, opts \\ []) do
    maybe_apply(Bonfire.Federate.ActivityPub.AdapterUtils, :is_local?, [thing, opts], opts)
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

  def indexing_format_created(object) do
    # current_user = current_user(opts)

    case object do
      %{
        created: %{creator: %{id: _} = creator}
      } ->
        indexing_format_creator(creator)

      %{
        creator: %{id: _} = creator
      } ->
        indexing_format_creator(creator)

      %{
        activity: %{created: %{creator: %{id: _} = creator}}
      } ->
        indexing_format_creator(creator)

      %{
        creator_id: creator_id,
        activity: %{
          subject: %{profile: %{id: id} = _profile, character: _} = subject
        }
      } ->
        indexing_format_creator(subject)

      %{
        created: %{creator_id: creator_id},
        activity: %{
          subject: %{profile: %{id: id} = _profile, character: _} = subject
        }
      } ->
        indexing_format_creator(subject)

      %{
        activity: %{
          created: %{creator_id: creator_id},
          subject: %{profile: %{id: id} = _profile, character: _} = subject
        }
      } ->
        indexing_format_creator(subject)

      %{
        object: %{creator_id: creator_id}
      } ->
        indexing_format_creator(Bonfire.Me.Users.by_id(creator_id))

      %{creator_id: creator_id} ->
        indexing_format_creator(Bonfire.Me.Users.by_id(creator_id))

      %{
        activity: %{created: %{creator_id: creator_id}}
      } ->
        creator =
          indexing_format_creator(Bonfire.Me.Users.by_id(creator_id))

      %{
        activity: %{
          subject: %{profile: %{id: _} = profile, character: _} = subject
        }
        # The indexer is written in terms of the inserted object, so changesets need fake inserting
      } ->
        indexing_format_creator(subject)

      %{
        activity: %{subject_id: subject_id}
      } ->
        indexing_format_creator(Bonfire.Me.Users.by_id(subject_id))

      _ ->
        warn("could not find a creator")
        debug(object)
        nil
    end
  end

  def indexing_format_creator(user_etc) do
    %{
      "creator" => %{
        "id" => id(user_etc),
        #  FIXME: should not assume User here
        "index_type" => Types.module_to_str(object_type(user_etc)),
        "profile" => Bonfire.Me.Profiles.indexing_object_format(e(user_etc, :profile, nil)),
        "character" => Bonfire.Me.Characters.indexing_object_format(e(user_etc, :character, nil))
      }
    }
  end
end
