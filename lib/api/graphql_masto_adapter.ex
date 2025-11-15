if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.Me.API.GraphQLMasto.Adapter do
    @moduledoc "Account/User related API endpoints for Mastodon-compatible client apps, powered by the GraphQL API (see `Bonfire.Me.API.GraphQL`)"

    # use Bonfire.UI.Common.Web, :controller
    use Bonfire.Common.Utils
    use Arrows
    import Untangle

    use AbsintheClient,
      schema: Bonfire.API.GraphQL.Schema,
      action: [mode: :internal]

    alias Bonfire.API.GraphQL.RestAdapter
    alias Bonfire.Common.Enums

    @user_profile "
    id
    created_at: date_created
    profile {
      avatar: icon
      avatar_static: icon
      header: image
      header_static: image
      # location
      display_name: name
      note: summary
      website
    }
    character {
      username
      acct: username
      url: canonical_uri
    }"
    def user_profile_query, do: @user_profile

    @graphql "query ($filter: CharacterFilters) {
      user(filter: $filter) {
        #{@user_profile}
    }}"
    def user(params, conn) do
      user = graphql(conn, :user, debug(params))

      RestAdapter.return(:user, user, conn, &prepare_user/1)
    end

    @graphql "query {
        me { 
         user { #{@user_profile} }
      }}"
    def me(params \\ %{}, conn),
      do: graphql(conn, :me, params) |> RestAdapter.return(:me, ..., conn, &prepare_user/1)

    def get_preferences(_params \\ %{}, conn) do
      # TODO 
      Phoenix.Controller.json(conn, %{
        "posting:default:visibility" => "public",
        "posting:default:sensitive" => false,
        "posting:default:language" => "en",
        "reading:expand:media" => "default",
        "reading:expand:spoilers" => false
      })
    end

    def prepare_user(data) do
      # TODO: we need to load settings for the user
      user = e(data, :user, nil)
      # |> debug("daaata")

      indexable = Bonfire.Common.Extend.module_enabled?(Bonfire.Search.Indexer, user)

      discoverable =
        Bonfire.Common.Settings.get([Bonfire.Me.Users, :undiscoverable], nil, current_user: user) !=
          true

      %{
        "indexable" => indexable,
        "discoverable" => discoverable,
        # ^ note some clients don't accept nil for note
        "created_at" => DatesTimes.date_from_pointer(user) ~> DateTime.to_iso8601(),
        "uri" => e(user, :character, :url, nil),
        "source" => %{
          # TODO: source field only on me query?
          "indexable" => indexable,
          "discoverable" => discoverable,
          "note" => e(user, :profile, :note, ""),
          # TODO: also implement these fields:
          "follow_requests_count" => 5,
          "hide_collections" => false,
          "attribution_domains" => [],
          "privacy" => "public",
          "sensitive" => false,
          "language" => ""
        },

        # TODO: also implement these fields:
        "locked" => false,
        "fields" => [],
        "emojis" => [],
        "bot" => false,
        "group" => false,
        "noindex" => false,
        "moved" => nil,
        "memorial" => nil,
        "suspended" => false,
        "limited" => false,
        "last_status_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "statuses_count" => 1,
        "followers_count" => 1,
        "following_count" => 1,
        "hide_collections" => false,
        "roles" => [],
        "role" => nil
      }
      |> Map.merge(
        user
        |> Enums.maybe_flatten()
        |> Enums.stringify_keys()
      )
      |> Map.put("note", Text.maybe_markdown_to_html(e(user, :profile, :note, nil)) || "")
      |> debug("prepared user for API")
    end
  end
end
