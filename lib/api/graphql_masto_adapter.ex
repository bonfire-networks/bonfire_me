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

    # Mutes and Blocks endpoints
    alias Bonfire.Boundaries.Blocks
    alias Bonfire.API.MastoCompat.Mappers
    alias Bonfire.API.MastoCompat.Schemas

    @doc "List muted accounts for current user"
    def mutes(_params, conn) do
      current_user = conn.assigns[:current_user]

      if is_nil(current_user) do
        RestAdapter.error_fn({:error, :unauthorized}, conn)
      else
        # Get silenced users (Mastodon "mute" = Bonfire "silence")
        circles = Blocks.list(:silence, current_user: current_user)
        accounts = extract_accounts_from_circles(circles, current_user)
        Phoenix.Controller.json(conn, accounts)
      end
    end

    @doc "List blocked accounts for current user"
    def blocks(_params, conn) do
      current_user = conn.assigns[:current_user]

      if is_nil(current_user) do
        RestAdapter.error_fn({:error, :unauthorized}, conn)
      else
        # Mastodon "block" = Bonfire ghost + silence (full isolation)
        # Get users who are BOTH ghosted AND silenced
        ghost_circles = Blocks.list(:ghost, current_user: current_user)
        silence_circles = Blocks.list(:silence, current_user: current_user)

        ghosted_ids = extract_user_ids_from_circles(ghost_circles)
        silenced_ids = extract_user_ids_from_circles(silence_circles)

        # Only return users who are in BOTH lists (full block)
        blocked_ids = MapSet.intersection(MapSet.new(ghosted_ids), MapSet.new(silenced_ids))

        accounts =
          ghost_circles
          |> extract_users_from_circles()
          |> Enum.filter(fn user -> MapSet.member?(blocked_ids, id(user)) end)
          |> Enum.map(&Mappers.Account.from_user(&1, current_user: current_user))
          |> Enum.reject(&is_nil/1)

        Phoenix.Controller.json(conn, accounts)
      end
    end

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

    defp handle_block_action(conn, target_id, action) do
      current_user = conn.assigns[:current_user]

      if is_nil(current_user) do
        RestAdapter.error_fn({:error, :unauthorized}, conn)
      else
        result =
          case action do
            # Mastodon "mute" = Bonfire "silence" (user can't reach you)
            :mute -> Blocks.block(target_id, :silence, current_user: current_user)
            :unmute -> Blocks.unblock(target_id, :silence, current_user: current_user)
            # Mastodon "block" = Bonfire default (both silence + ghost = full isolation)
            :block -> Blocks.block(target_id, nil, current_user: current_user)
            :unblock -> Blocks.unblock(target_id, nil, current_user: current_user)
          end

        case result do
          {:ok, _} ->
            # Query actual state after the action completes
            relationship = build_relationship(current_user, target_id)
            Phoenix.Controller.json(conn, relationship)

          {:error, reason} ->
            RestAdapter.error_fn({:error, reason}, conn)
        end
      end
    end

    defp extract_accounts_from_circles(circles, current_user) do
      circles
      |> extract_users_from_circles()
      |> Enum.map(&Mappers.Account.from_user(&1, current_user: current_user))
      |> Enum.reject(&is_nil/1)
    end

    defp extract_users_from_circles(circles) do
      circles
      |> Enum.flat_map(fn circle ->
        case circle do
          %{encircles: encircles} when is_list(encircles) ->
            Enum.map(encircles, & &1.subject)

          _ ->
            []
        end
      end)
      |> Enum.reject(&is_nil/1)
    end

    defp extract_user_ids_from_circles(circles) do
      circles
      |> extract_users_from_circles()
      |> Enum.map(&id/1)
      |> Enum.reject(&is_nil/1)
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
