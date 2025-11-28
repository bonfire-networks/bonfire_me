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
      peered {
        canonical_uri
      }
    }"
    def user_profile_query, do: @user_profile

    @graphql "query ($filter: CharacterFilters) {
      user(filter: $filter) {
        #{@user_profile}
    }}"
    def user(params, conn) do
      user = graphql(conn, :user, params)

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

    # Mutes and Blocks endpoints - using GraphQL
    alias Bonfire.Boundaries.Blocks
    alias Bonfire.API.MastoCompat.Mappers
    alias Bonfire.API.MastoCompat.Schemas

    # GraphQL queries for listing muted/blocked users
    # Helper to list restricted accounts (mutes/blocks)
    defp list_restricted_accounts(conn, query_name, data_key) do
      case graphql(conn, query_name, %{}) do
        %{data: data} when is_map(data) ->
          current_user = conn.assigns[:current_user]
          users = Map.get(data, data_key, [])

          accounts =
            users
            |> Enum.map(&prepare_user/1)
            |> Enum.reject(&is_nil/1)
            |> Enum.map(&Mappers.Account.from_user(&1, current_user: current_user))
            |> Enum.reject(&is_nil/1)

          Phoenix.Controller.json(conn, accounts)

        %{errors: errors} ->
          RestAdapter.error_fn({:error, errors}, conn)

        _ ->
          Phoenix.Controller.json(conn, [])
      end
    end

    @graphql "query {
      muted_users {
        #{@user_profile}
      }
    }"
    @doc "List muted accounts for current user"
    def mutes(_params, conn), do: list_restricted_accounts(conn, :mutes, :muted_users)

    @graphql "query {
      blocked_users {
        #{@user_profile}
      }
    }"
    @doc "List blocked accounts for current user"
    def blocks(_params, conn), do: list_restricted_accounts(conn, :blocks, :blocked_users)

    @doc "Mute an account"
    def mute_account(%{"id" => id}, conn), do: handle_block_action(conn, id, :mute)

    @doc "Unmute an account"
    def unmute_account(%{"id" => id}, conn), do: handle_block_action(conn, id, :unmute)

    @doc "Block an account"
    def block_account(%{"id" => id}, conn), do: handle_block_action(conn, id, :block)

    @doc "Unblock an account"
    def unblock_account(%{"id" => id}, conn), do: handle_block_action(conn, id, :unblock)

    @doc """
    Get relationships between the current user and given accounts.
    Mastodon API: GET /api/v1/accounts/relationships?id[]=1&id[]=2
    """
    def relationships(params, conn) do
      current_user = conn.assigns[:current_user]

      if is_nil(current_user) do
        RestAdapter.error_fn({:error, :unauthorized}, conn)
      else
        # Get list of account IDs from query params
        # Mastodon sends as ?id[]=1&id[]=2 or ?id=1&id=2
        ids =
          case params do
            %{"id" => ids} when is_list(ids) -> ids
            %{"id" => id} when is_binary(id) -> [id]
            _ -> []
          end

        # TODO: Check follow status when Follows module is integrated
        relationships = Enum.map(ids, &build_relationship(current_user, &1))

        Phoenix.Controller.json(conn, relationships)
      end
    end

    # GraphQL mutations for block/mute actions (must be public for @graphql to work)
    @graphql "mutation ($id: ID!) {
      block_user(id: $id) {
        id
      }
    }"
    def do_block_user(conn, id) do
      graphql(conn, :do_block_user, %{"id" => id})
    end

    @graphql "mutation ($id: ID!) {
      unblock_user(id: $id) {
        id
      }
    }"
    def do_unblock_user(conn, id) do
      graphql(conn, :do_unblock_user, %{"id" => id})
    end

    @graphql "mutation ($id: ID!) {
      mute_user(id: $id) {
        id
      }
    }"
    def do_mute_user(conn, id) do
      graphql(conn, :do_mute_user, %{"id" => id})
    end

    @graphql "mutation ($id: ID!) {
      unmute_user(id: $id) {
        id
      }
    }"
    def do_unmute_user(conn, id) do
      graphql(conn, :do_unmute_user, %{"id" => id})
    end

    defp handle_block_action(conn, target_id, action) do
      current_user = conn.assigns[:current_user]

      if is_nil(current_user) do
        RestAdapter.error_fn({:error, :unauthorized}, conn)
      else
        result =
          case action do
            # Mastodon "mute" = Bonfire "silence" (user can't reach you)
            :mute -> do_mute_user(conn, target_id)
            :unmute -> do_unmute_user(conn, target_id)
            # Mastodon "block" = Bonfire ghost + silence (full isolation)
            :block -> do_block_user(conn, target_id)
            :unblock -> do_unblock_user(conn, target_id)
          end

        case result do
          %{data: data} when is_map(data) ->
            # Query actual state after the action completes
            relationship = build_relationship(current_user, target_id)
            Phoenix.Controller.json(conn, relationship)

          %{errors: errors} ->
            RestAdapter.error_fn({:error, errors}, conn)

          _ ->
            RestAdapter.error_fn({:error, :unexpected_response}, conn)
        end
      end
    end

    @doc "Build a Mastodon Relationship object by querying actual state"
    defp build_relationship(current_user, target_id) do
      blocking = Blocks.is_blocked?(target_id, :ghost, current_user: current_user)
      muting = Blocks.is_blocked?(target_id, :silence, current_user: current_user)

      Schemas.Relationship.new(%{
        "id" => to_string(target_id),
        "blocking" => blocking,
        "muting" => muting,
        "muting_notifications" => muting
      })
    end

    # Handle nil user (can happen with old/deleted accounts in paginated results)
    def prepare_user(nil), do: nil

    def prepare_user(data) do
      # TODO: we need to load settings for the user
      # Note: data is already the user object (extracted by RestAdapter.return)
      user = data

      indexable = Bonfire.Common.Extend.module_enabled?(Bonfire.Search.Indexer, user)

      discoverable =
        Bonfire.Common.Settings.get([Bonfire.Me.Users, :undiscoverable], nil, current_user: user) !=
          true

      created_at =
        case user[:created_at] do
          %DateTime{} = dt ->
            DateTime.to_iso8601(dt)

          _ ->
            DatesTimes.date_from_pointer(user) ~> DateTime.to_iso8601() ||
              DateTime.utc_now() |> DateTime.to_iso8601()
        end

      %{
        "indexable" => indexable,
        "discoverable" => discoverable,
        # ^ note some clients don't accept nil for note
        "created_at" => created_at,
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
        "moved" => nil,
        "memorial" => nil,
        "role" => nil
      }
      |> Map.merge(
        user
        # Recursively convert Ecto structs to maps
        |> Enums.struct_to_map(true)
        |> Enums.maybe_flatten()
        |> Enums.stringify_keys()
        |> case do
          nil ->
            %{}

          map when is_map(map) ->
            map

          other ->
            error(other, "Unexpected user data format in prepare_user")
            %{}
        end
      )
      |> Map.put("note", Text.maybe_markdown_to_html(e(user, :profile, :note, nil)) || "")
      # make sure non-nullable fields are not null
      |> Enums.set_default_values(%{
        "avatar" => "",
        "header" => "",
        # TODO: also implement any these fields still missing:
        "locked" => false,
        "fields" => [],
        "emojis" => [],
        "bot" => false,
        "group" => false,
        "noindex" => false,
        "suspended" => false,
        "limited" => false,
        "hide_collections" => false,
        "roles" => [],
        "statuses_count" => 1,
        "followers_count" => 1,
        "following_count" => 1,
        "last_status_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      })
    end
  end
end
