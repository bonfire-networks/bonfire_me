if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.Me.API.GraphQLMasto.Adapter do
    @moduledoc """
    Account/User related API endpoints for Mastodon-compatible client apps.

    This adapter handles:
    - User profile queries (GET /api/v1/accounts/:id, /api/v1/accounts/verify_credentials)
    - Follow/unfollow actions
    - Followers/following lists with batch-loaded stats
    - Account relationships

    User → Mastodon Account transformation is delegated to `Mappers.Account`.
    """

    use Bonfire.Common.Utils
    use Arrows
    import Untangle

    use AbsintheClient,
      schema: Bonfire.API.GraphQL.Schema,
      action: [mode: :internal]

    alias Bonfire.API.GraphQL.RestAdapter
    alias Bonfire.API.MastoCompat.{Mappers, PaginationHelpers}
    alias Bonfire.API.MastoCompat.Mappers.BatchLoader

    # Use fragment from local MastoFragments module
    @user_profile Bonfire.Me.API.MastoFragments.user_profile()

    @doc "Returns the GraphQL fragment for user profile queries"
    def user_profile_query, do: @user_profile

    @graphql "query ($filter: CharacterFilters) {
      user(filter: $filter) {
        #{@user_profile}
    }}"
    @doc "Get a user profile by filter (id, username, etc)"
    def user(params, conn) do
      graphql(conn, :user, params)
      |> RestAdapter.return(:user, ..., conn, &Mappers.Account.from_user/1)
    end

    @graphql "query {
        me {
         user { #{@user_profile} }
      }}"
    @doc "Get the current user's profile (verify_credentials)"
    def me(params \\ %{}, conn) do
      graphql(conn, :me, params)
      |> RestAdapter.return(:me, ..., conn, fn
        %{user: user} -> Mappers.Account.from_user(user)
        user -> Mappers.Account.from_user(user)
      end)
    end

    @doc "Get user preferences"
    def get_preferences(_params \\ %{}, conn) do
      # TODO: implement actual preferences
      Phoenix.Controller.json(conn, %{
        "posting:default:visibility" => "public",
        "posting:default:sensitive" => false,
        "posting:default:language" => "en",
        "reading:expand:media" => "default",
        "reading:expand:spoilers" => false
      })
    end

    @doc "Follow an account"
    def follow_account(%{"id" => id}, conn), do: handle_follow_action(conn, id, :follow)

    @doc "Unfollow an account"
    def unfollow_account(%{"id" => id}, conn), do: handle_follow_action(conn, id, :unfollow)

    defp handle_follow_action(conn, target_id, action) do
      current_user = conn.assigns[:current_user]

      if is_nil(current_user) do
        RestAdapter.error_fn({:error, :unauthorized}, conn)
      else
        alias Bonfire.Social.Graph.Follows
        alias Bonfire.Boundaries.API.GraphQLMasto.Adapter, as: BoundariesAdapter

        result =
          case action do
            :follow -> Follows.follow(current_user, target_id, [])
            :unfollow -> Follows.unfollow(current_user, target_id, [])
          end

        case result do
          {:ok, _} ->
            relationship = BoundariesAdapter.build_relationship(current_user, target_id)
            RestAdapter.json(conn, relationship)

          {:error, reason} ->
            RestAdapter.error_fn({:error, reason}, conn)

          _ ->
            relationship = BoundariesAdapter.build_relationship(current_user, target_id)
            RestAdapter.json(conn, relationship)
        end
      end
    end

    @doc "List followers of an account"
    def followers(account_id, params, conn) do
      list_follow_connections(account_id, params, conn, :followers)
    end

    @doc "List accounts that an account is following"
    def following(account_id, params, conn) do
      list_follow_connections(account_id, params, conn, :following)
    end

    defp list_follow_connections(account_id, params, conn, direction) do
      alias Bonfire.Social.Graph.Follows

      limit = PaginationHelpers.validate_limit(params["limit"])
      pagination_opts = PaginationHelpers.build_pagination_opts(params, limit) |> Map.new()

      case Bonfire.Me.Users.by_id(account_id) do
        {:ok, user} ->
          opts = [pagination: pagination_opts, current_user: conn.assigns[:current_user]]

          {list_fn, user_field} =
            case direction do
              :followers -> {&Follows.list_followers/2, :subject}
              :following -> {&Follows.list_followed/2, :object}
            end

          case list_fn.(user, opts) do
            %{edges: edges, page_info: page_info} ->
              accounts = map_follow_edges_to_accounts(edges, user_field, conn)
              conn = PaginationHelpers.add_simple_link_headers(conn, %{}, page_info, [])
              RestAdapter.json(conn, accounts)

            edges when is_list(edges) ->
              accounts = map_follow_edges_to_accounts(edges, user_field, conn)
              RestAdapter.json(conn, accounts)

            _ ->
              RestAdapter.json(conn, [])
          end

        _ ->
          RestAdapter.error_fn({:error, :not_found}, conn)
      end
    end

    defp map_follow_edges_to_accounts(edges, user_field, conn) do
      current_user = conn.assigns[:current_user]

      users =
        edges
        |> Enum.map(fn edge ->
          e(edge, user_field, nil) || e(edge, :edge, user_field, nil)
        end)
        |> Enum.reject(&is_nil/1)

      BatchLoader.map_accounts(users, current_user: current_user)
    end

    @doc """
    Get relationships between the current user and given accounts.
    Mastodon API: GET /api/v1/accounts/relationships?id[]=1&id[]=2
    """
    def relationships(params, conn) do
      current_user = conn.assigns[:current_user]

      if is_nil(current_user) do
        RestAdapter.error_fn({:error, :unauthorized}, conn)
      else
        ids =
          case params do
            %{"id" => ids} when is_list(ids) -> ids
            %{"id" => id} when is_binary(id) -> [id]
            _ -> []
          end

        alias Bonfire.Boundaries.API.GraphQLMasto.Adapter, as: BoundariesAdapter
        relationships = Enum.map(ids, &BoundariesAdapter.build_relationship(current_user, &1))

        RestAdapter.json(conn, relationships)
      end
    end

    @doc """
    Prepare user data for Mastodon API response.

    DEPRECATED: Use `Mappers.Account.from_user/2` directly instead.
    This function is kept for backward compatibility with code that
    still calls MeAdapter.prepare_user.
    """
    def prepare_user(nil), do: nil
    def prepare_user(nil, _opts), do: nil
    def prepare_user(user, opts \\ []), do: Mappers.Account.from_user(user, opts)
  end
end
