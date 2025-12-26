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
    use Bonfire.Common.Repo
    use Arrows
    import Untangle

    use AbsintheClient,
      schema: Bonfire.API.GraphQL.Schema,
      action: [mode: :internal]

    alias Bonfire.API.GraphQL.RestAdapter
    alias Bonfire.API.MastoCompat.{Mappers, PaginationHelpers, Fragments}
    alias Bonfire.API.MastoCompat.Mappers.BatchLoader

    # Use centralized fragments from bonfire_api_graphql
    @user_profile Fragments.user_profile()

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

    @doc """
    Update the authenticated user's profile.
    Mastodon API: PATCH /api/v1/accounts/update_credentials
    """
    def update_credentials(params, conn) do
      current_user = conn.assigns[:current_user]

      if is_nil(current_user) do
        RestAdapter.error_fn({:error, :unauthorized}, conn)
      else
        profile_params = build_profile_params(params)

        with {:ok, image_params} <- handle_image_uploads(current_user, params),
             merged_params <- merge_profile_and_images(profile_params, image_params),
             {:ok, updated_user} <- Bonfire.Me.Users.update(current_user, merged_params) do
          case Bonfire.Me.Users.by_id(updated_user.id) do
            {:ok, user} -> RestAdapter.json(conn, Mappers.Account.from_user(user))
            _ -> RestAdapter.json(conn, Mappers.Account.from_user(updated_user))
          end
        else
          {:error, reason} -> RestAdapter.error_fn({:error, reason}, conn)
        end
      end
    end

    defp build_profile_params(params) do
      profile =
        %{}
        |> maybe_put_param("name", params["display_name"])
        |> maybe_put_param("summary", params["note"])

      %{"profile" => profile}
    end

    defp maybe_put_param(map, _key, nil), do: map
    defp maybe_put_param(map, _key, ""), do: map
    defp maybe_put_param(map, key, value), do: Map.put(map, key, value)

    defp handle_image_uploads(user, params) do
      avatar_result = maybe_upload_image(user, params["avatar"], :icon)
      header_result = maybe_upload_image(user, params["header"], :image)

      with {:ok, avatar_media} <- avatar_result,
           {:ok, header_media} <- header_result do
        image_params =
          %{}
          |> maybe_put_media_id(:icon_id, avatar_media)
          |> maybe_put_media_id(:image_id, header_media)

        {:ok, image_params}
      end
    end

    defp maybe_upload_image(_user, nil, _type), do: {:ok, nil}
    defp maybe_upload_image(_user, "", _type), do: {:ok, nil}

    defp maybe_upload_image(user, %Plug.Upload{} = upload, :icon) do
      Bonfire.Files.IconUploader.upload(user, upload, %{})
    end

    defp maybe_upload_image(user, %Plug.Upload{} = upload, :image) do
      Bonfire.Files.BannerUploader.upload(user, upload, %{})
    end

    defp maybe_put_media_id(map, _key, nil), do: map
    defp maybe_put_media_id(map, key, %{id: id}), do: Map.put(map, key, id)
    defp maybe_put_media_id(map, _key, _), do: map

    defp merge_profile_and_images(profile_params, image_params) do
      profile = Map.get(profile_params, "profile", %{})
      updated_profile = Map.merge(profile, image_params)
      Map.put(profile_params, "profile", updated_profile)
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

    # Follow Requests endpoints

    @doc "List incoming follow requests (GET /api/v1/follow_requests)"
    def follow_requests(_params, conn), do: list_follow_requests(conn, :incoming)

    @doc "List outgoing follow requests (GET /api/v1/follow_requests/outgoing)"
    def follow_requests_outgoing(_params, conn), do: list_follow_requests(conn, :outgoing)

    defp list_follow_requests(conn, direction) do
      current_user = conn.assigns[:current_user]

      if is_nil(current_user) do
        RestAdapter.error_fn({:error, :unauthorized}, conn)
      else
        alias Bonfire.Social.Requests
        alias Bonfire.Data.Social.Follow

        # Preload the user profile/character based on direction
        # Use :subject/:object_profile to get the user's profile and character loaded
        preload =
          case direction do
            :incoming -> :subject
            :outgoing -> :object_profile
          end

        requests =
          case direction do
            :incoming ->
              Requests.list_my_requesters(
                current_user: current_user,
                type: Follow,
                preload: preload
              )

            :outgoing ->
              Requests.list_my_requested(
                current_user: current_user,
                type: Follow,
                preload: preload
              )
          end

        accounts =
          requests
          |> Enum.map(&extract_request_user(&1, direction))
          |> Enum.map(&Mappers.Account.from_user(&1, skip_expensive_stats: true))
          |> Enum.reject(&is_nil/1)

        RestAdapter.json(conn, accounts)
      end
    end

    defp extract_request_user(request, :incoming), do: e(request, :edge, :subject, nil)
    defp extract_request_user(request, :outgoing), do: e(request, :edge, :object, nil)

    @doc "Accept/authorize a follow request (POST /api/v1/follow_requests/:account_id/authorize)"
    def authorize_follow_request(account_id, conn),
      do: handle_follow_request_action(conn, account_id, :authorize)

    @doc "Reject a follow request (POST /api/v1/follow_requests/:account_id/reject)"
    def reject_follow_request(account_id, conn),
      do: handle_follow_request_action(conn, account_id, :reject)

    defp handle_follow_request_action(conn, account_id, action) do
      current_user = conn.assigns[:current_user]

      if is_nil(current_user) do
        RestAdapter.error_fn({:error, :unauthorized}, conn)
      else
        alias Bonfire.Social.Graph.Follows
        alias Bonfire.Boundaries.API.GraphQLMasto.Adapter, as: BoundariesAdapter

        result =
          case action do
            :authorize -> Follows.accept_from(account_id, current_user: current_user)
            :reject -> Follows.reject(account_id, current_user, [])
          end

        case result do
          {:ok, _} ->
            relationship = BoundariesAdapter.build_relationship(current_user, account_id)
            RestAdapter.json(conn, relationship)

          {:error, :not_found} ->
            RestAdapter.error_fn({:error, :not_found}, conn)

          {:error, reason} ->
            RestAdapter.error_fn({:error, reason}, conn)
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
    Lookup an account by webfinger address.
    Mastodon API: GET /api/v1/accounts/lookup?acct=username or acct=username@domain
    """
    def lookup_account(params, conn) do
      case lookup_by_acct(params["acct"]) do
        {:ok, user} -> RestAdapter.json(conn, Mappers.Account.from_user(user))
        _ -> RestAdapter.error_fn({:error, :not_found}, conn)
      end
    end

    defp lookup_by_acct(nil), do: {:error, :not_found}
    defp lookup_by_acct(""), do: {:error, :not_found}

    defp lookup_by_acct(acct) do
      acct = String.trim_leading(acct, "@")

      case String.split(acct, "@", parts: 2) do
        [username, domain] -> lookup_by_acct(username, domain)
        [username] -> Bonfire.Me.Users.by_username(username)
      end
    end

    defp lookup_by_acct(username, domain) do
      if domain == Bonfire.Common.URIs.base_domain() do
        Bonfire.Me.Users.by_username(username)
      else
        fetch_remote_user("#{username}@#{domain}")
      end
    end

    defp fetch_remote_user(webfinger) do
      if module_enabled?(ActivityPub.Actor) do
        with {:ok, actor} <- ActivityPub.Actor.fetch_by_username(webfinger),
             pointer_id when not is_nil(pointer_id) <- e(actor, :pointer_id, nil) do
          Bonfire.Me.Users.by_id(pointer_id)
        else
          _ -> {:error, :not_found}
        end
      else
        {:error, :not_found}
      end
    end

    @doc """
    Search for accounts by username or display name.
    Mastodon API: GET /api/v1/accounts/search?q=query
    """
    def search_accounts(params, conn) do
      current_user = conn.assigns[:current_user]
      query = params["q"] || ""
      limit = PaginationHelpers.validate_limit(params["limit"] || 10, max: 40)

      if String.trim(query) == "" do
        RestAdapter.json(conn, [])
      else
        users =
          case Bonfire.Me.Users.search(query, limit: limit, current_user: current_user) do
            users when is_list(users) ->
              users

            %{edges: edges} when is_list(edges) ->
              Enum.map(edges, &e(&1, :edge, nil)) |> Enum.reject(&is_nil/1)

            _ ->
              []
          end

        accounts =
          users
          |> repo().maybe_preload([:profile, :character])
          |> BatchLoader.map_accounts(current_user: current_user)

        RestAdapter.json(conn, accounts)
      end
    end

    @doc """
    Get suggested accounts to follow.

    Mastodon API v2: GET /api/v2/suggestions

    Returns accounts from the curated "Suggested Profiles" circle maintained by admins/mods.
    Falls back to discoverable users from the local instance if the circle is empty.

    ## Parameters

    - `limit` - Maximum number of suggestions to return (default: 40, max: 80)

    See: https://docs.joinmastodon.org/methods/suggestions/#v2
    """
    def suggestions(params, conn) do
      current_user = conn.assigns[:current_user]

      if is_nil(current_user) do
        RestAdapter.error_fn({:error, :unauthorized}, conn)
      else
        limit = parse_limit(params, default: 40, max: 80)

        # Get users from the suggested profiles circle (curated by admins)
        users =
          get_suggested_profiles(current_user, limit)
          |> exclude_current_user(current_user)

        suggestions =
          Mappers.Suggestion.from_users(users,
            source: "staff",
            sources: ["featured"],
            skip_expensive_stats: true
          )

        RestAdapter.json(conn, suggestions)
      end
    end

    defp parse_limit(params, opts) do
      default = Keyword.get(opts, :default, 40)
      max = Keyword.get(opts, :max, 80)

      case params do
        %{"limit" => limit} when is_binary(limit) ->
          case Integer.parse(limit) do
            {n, _} -> min(max(n, 1), max)
            :error -> default
          end

        %{"limit" => limit} when is_integer(limit) ->
          min(max(limit, 1), max)

        _ ->
          default
      end
    end

    defp get_suggested_profiles(current_user, limit) do
      alias Bonfire.Boundaries.Circles
      alias Bonfire.Boundaries.Scaffold.Instance
      alias Bonfire.Common.Needles

      # Get members from the suggested profiles circle (curated by admins)
      circle_id = Instance.suggested_profiles_circle()

      # list_members preloads subject: [:character, :profile, :named]
      case Circles.list_members(circle_id, current_user: current_user, limit: limit) do
        %{edges: members} when is_list(members) and length(members) > 0 ->
          members
          |> Enum.map(&e(&1, :subject, nil))
          |> Enum.reject(&is_nil/1)
          # Convert Needle.Pointer to actual User structs
          |> Enum.map(&Needles.follow!(&1, []))
          |> Enum.reject(&is_nil/1)

        _ ->
          []
      end
    end

    defp exclude_current_user(users, current_user) when is_list(users) do
      current_user_id = uid(current_user)

      Enum.reject(users, fn user ->
        uid(user) == current_user_id
      end)
    end

    defp exclude_current_user(users, _), do: users
  end
end
