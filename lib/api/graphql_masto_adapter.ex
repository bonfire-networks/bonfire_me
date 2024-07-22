if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.Me.API.GraphQLMasto.Adapter do
    @moduledoc "Account/User related API endpoints for Mastodon-compatible client apps, powered by the GraphQL API (see `Bonfire.Me.API.GraphQL`)"

    # use Bonfire.UI.Common.Web, :controller
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

    def prepare_user(user) do
      # TODO: implement these fields
      %{
        "locked" => false,
        "followers_count" => 1,
        "following_count" => 1,
        "statuses_count" => 1,
        "last_status_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        # TODO: this field only on me query
        "source" => %{},
        "emojis" => [],
        "fields" => []
      }
      |> Map.merge(
        user
        |> Enums.maybe_flatten()
        # because some clients don't accept nil
        |> Enums.map_put_default(:note, "")
      )
      |> debug()
    end
  end
end
