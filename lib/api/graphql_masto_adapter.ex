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

    # Custom pipeline to set up context with dataloader
    def absinthe_pipeline(schema, opts) do
      context = Keyword.get(opts, :context, %{})

      context_with_loader =
        if Map.has_key?(context, :loader) do
          context
        else
          schema.context(context)
        end

      AbsintheClient.default_pipeline(schema, Keyword.put(opts, :context, context_with_loader))
    end

    alias Bonfire.Social.Graph.Follows
    alias Bonfire.Boundaries.API.GraphQLMasto.Adapter, as: BoundariesAdapter

    # Use centralized fragments from bonfire_api_graphql
    @account_fields Fragments.account_fields()

    @graphql "query ($filter: CharacterFilters) {
      user(filter: $filter) {
        #{@account_fields}
    }}"
    @doc "Get a user profile by id or username (`GET /api/v1/accounts/:id`)"
    def user(params, conn) do
      graphql(conn, :user, params)
      |> RestAdapter.return(:user, ..., conn, &Mappers.Account.from_user/1)
    end

    @graphql "query {
        me {
         follow_requests_count
         user { #{@account_fields} }
      }}"
    @doc "Get the current user's profile (verify_credentials)"
    def me(params \\ %{}, conn) do
      # Mastodon returns 403 for unconfirmed accounts on verify_credentials
      confirmed_conn = Bonfire.API.GraphQL.Plugs.RequireConfirmed.call(conn, [])

      if confirmed_conn.halted do
        confirmed_conn
      else
        graphql(conn, :me, params)
        |> RestAdapter.return(:me, ..., conn, fn
          %{user: %{} = user} = me ->
            own_account_json(user, me[:follow_requests_count], conn.assigns[:current_user])

          _no_user ->
            nil
        end)
      end
    end

    @doc "Get user preferences"
    def get_preferences(_params \\ %{}, conn) do
      # TODO: the other preferences
      Phoenix.Controller.json(conn, %{
        "posting:default:visibility" => default_visibility(conn.assigns[:current_user]),
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
          own_account(conn, updated_user)
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

    @doc "Follow an account through GraphQL. `notify` turns notifications of their posts on or off (`Bonfire.Notify.Bells`), and leaving it out leaves them as they were, as Mastodon does for an existing follow."
    def follow_account(%{"id" => id} = params, conn),
      do: handle_follow_action(conn, id, :follow, notify_param(params["notify"]))

    defp notify_param(notify) when notify in [true, "true", "1", 1], do: true
    defp notify_param(notify) when notify in [false, "false", "0", 0], do: false
    defp notify_param(_), do: nil

    @doc "Unfollow an account through GraphQL."
    def unfollow_account(%{"id" => id}, conn), do: handle_follow_action(conn, id, :unfollow)

    defp handle_follow_action(conn, target_id, action, notify \\ nil) do
      RestAdapter.with_current_user(conn, fn current_user ->
        # the same documents `Follows.nomad/4` runs through GraphQL
        query = Bonfire.Social.Graph.Follows.graphql_document(action)

        variables = %{"id" => target_id}

        case Absinthe.run(query, Bonfire.API.GraphQL.Schema,
               variables: variables,
               context: Bonfire.API.GraphQL.Schema.context(%{current_user: current_user})
             ) do
          {:ok, %{errors: errors}} ->
            RestAdapter.error_fn(errors, conn)

          {:ok, %{data: _}} ->
            maybe_set_notify(current_user, target_id, notify)

            case read_relationship(current_user, target_id) do
              {:ok, relationship} -> RestAdapter.json(conn, relationship)
              {:error, error} -> RestAdapter.error_fn({:error, error}, conn)
            end

          {:error, error} ->
            RestAdapter.error_fn({:error, error}, conn)
        end
      end)
    end

    # asked rather than called, since this extension doesn't depend on `bonfire_notify`
    defp maybe_set_notify(_user, _target_id, nil), do: nil

    defp maybe_set_notify(user, target_id, true),
      do: maybe_apply(Bonfire.Notify.Bells, :enable, [user, target_id], fallback_return: nil)

    defp maybe_set_notify(user, target_id, false),
      do: maybe_apply(Bonfire.Notify.Bells, :disable, [user, target_id], fallback_return: nil)

    # which of these accounts the person has notifications of their posts on for, in one query
    defp notifying_ids(user, target_ids),
      do:
        maybe_apply(Bonfire.Notify.Bells, :enabled_ids, [user, target_ids], fallback_return: [])
        |> List.wrap()

    defp read_relationship(user, target_id, notifying? \\ nil)

    defp read_relationship(user, target_id, nil),
      do: read_relationship(user, target_id, target_id in notifying_ids(user, [target_id]))

    defp read_relationship(user, target_id, notifying?),
      do: BoundariesAdapter.read_relationship(user, target_id, notifying?)

    # Follow Requests endpoints

    @doc "List incoming follow requests (GET /api/v1/follow_requests)"
    def follow_requests(_params, conn), do: list_follow_requests(conn, :incoming)

    @doc "List outgoing follow requests (GET /api/v1/follow_requests/outgoing)"
    def follow_requests_outgoing(_params, conn), do: list_follow_requests(conn, :outgoing)

    @graphql "query ($first: Int, $after: String, $last: Int, $before: String) {
      me {
        follow_requests(first: $first, after: $after, last: $last, before: $before) {
          edges { node { #{@account_fields} } }
          page_info { start_cursor end_cursor has_next_page }
        }
      }
    }"
    def follow_requests_gql(params, conn), do: graphql(conn, :follow_requests_gql, params)

    @graphql "query ($first: Int, $after: String, $last: Int, $before: String) {
      me {
        follow_requests_outgoing(first: $first, after: $after, last: $last, before: $before) {
          edges { node { #{@account_fields} } }
          page_info { start_cursor end_cursor has_next_page }
        }
      }
    }"
    def follow_requests_outgoing_gql(params, conn),
      do: graphql(conn, :follow_requests_outgoing_gql, params)

    defp list_follow_requests(conn, direction) do
      RestAdapter.with_current_user(conn, fn _current_user ->
        # `max_id` pages on (`first`/`after`), `min_id` or `since_id` back (`last`/`before`)
        limit = PaginationHelpers.validate_limit(conn.params["limit"])

        vars =
          case conn.params["min_id"] || conn.params["since_id"] do
            before when is_binary(before) and before != "" ->
              %{"last" => limit, "before" => before}

            _ ->
              PaginationHelpers.maybe_add_cursor(
                %{"first" => limit},
                conn.params,
                "max_id",
                "after"
              )
          end

        {result, field} =
          case direction do
            :incoming -> {follow_requests_gql(vars, conn), :follow_requests}
            :outgoing -> {follow_requests_outgoing_gql(vars, conn), :follow_requests_outgoing}
          end

        case result do
          %{data: %{me: %{^field => %{} = connection}}} ->
            accounts =
              (connection[:edges] || [])
              |> Enum.map(&Mappers.Account.from_user(&1[:node]))
              |> Enum.reject(&is_nil/1)

            conn
            |> PaginationHelpers.add_simple_link_headers(%{}, connection[:page_info], [])
            |> RestAdapter.json(accounts)

          other ->
            graphql_error(other, conn)
        end
      end)
    end

    @doc "Accept/authorize a follow request (POST /api/v1/follow_requests/:account_id/authorize)"
    def authorize_follow_request(account_id, conn),
      do: handle_follow_request_action(conn, account_id, :authorize)

    @doc "Reject a follow request (POST /api/v1/follow_requests/:account_id/reject)"
    def reject_follow_request(account_id, conn),
      do: handle_follow_request_action(conn, account_id, :reject)

    defp handle_follow_request_action(conn, account_id, action) do
      RestAdapter.with_current_user(conn, fn current_user ->
        result =
          case action do
            :authorize -> Follows.accept_from(account_id, current_user: current_user)
            :reject -> Follows.reject(account_id, current_user, [])
          end

        case result do
          {:ok, _} ->
            case read_relationship(current_user, account_id) do
              {:ok, relationship} -> RestAdapter.json(conn, relationship)
              {:error, error} -> RestAdapter.error_fn({:error, error}, conn)
            end

          {:error, :not_found} ->
            RestAdapter.error_fn({:error, :not_found}, conn)

          {:error, reason} ->
            RestAdapter.error_fn({:error, reason}, conn)
        end
      end)
    end

    @doc "List followers of an account"
    def followers(account_id, params, conn) do
      list_follow_connections(account_id, params, conn, :followers)
    end

    @doc "List accounts that an account is following"
    def following(account_id, params, conn) do
      list_follow_connections(account_id, params, conn, :following)
    end

    @graphql "query ($filter: CharacterFilters, $first: Int, $after: String, $before: String) {
      user(filter: $filter) {
        followers(first: $first, after: $after, before: $before) {
          edges { node { #{@account_fields} } }
          page_info { start_cursor end_cursor has_next_page }
        }
      }
    }"
    def followers_gql(params, conn), do: graphql(conn, :followers_gql, params)

    @graphql "query ($filter: CharacterFilters, $first: Int, $after: String, $before: String) {
      user(filter: $filter) {
        following(first: $first, after: $after, before: $before) {
          edges { node { #{@account_fields} } }
          page_info { start_cursor end_cursor has_next_page }
        }
      }
    }"
    def following_gql(params, conn), do: graphql(conn, :following_gql, params)

    defp list_follow_connections(account_id, params, conn, direction) do
      # Mastodon's cursors, as `PaginationHelpers.build_pagination_opts/2` maps them, as relay args
      vars =
        params
        |> PaginationHelpers.build_pagination_opts(
          PaginationHelpers.validate_limit(params["limit"])
        )
        |> Enum.reduce(%{"filter" => %{"id" => account_id}}, fn
          {:limit, limit}, vars -> Map.put(vars, "first", limit)
          {cursor, value}, vars -> Map.put(vars, to_string(cursor), value)
        end)

      result =
        case direction do
          :followers -> followers_gql(vars, conn)
          :following -> following_gql(vars, conn)
        end

      case result do
        %{data: %{user: %{^direction => %{} = connection}}} ->
          accounts =
            (connection[:edges] || [])
            |> Enum.map(&Mappers.Account.from_user(&1[:node]))
            |> Enum.reject(&is_nil/1)

          conn =
            PaginationHelpers.add_simple_link_headers(conn, %{}, connection[:page_info], [])

          RestAdapter.json(conn, accounts)

        %{data: %{user: %{}}} = failed ->
          graphql_error(failed, conn)

        _ ->
          RestAdapter.error_fn({:error, :not_found}, conn)
      end
    end

    # Mastodon's limit per request
    @max_account_ids 40

    @doc """
    Get several accounts by id, in the order asked; ids that do not exist or that the reader may not see are left out.
    Mastodon API: GET /api/v1/accounts?id[]=1&id[]=2
    """
    def accounts(params, conn) do
      ids =
        case params do
          %{"id" => ids} when is_list(ids) -> ids
          %{"id" => id} when is_binary(id) -> [id]
          _ -> []
        end
        |> Enum.uniq()
        |> Enum.take(@max_account_ids)

      by_id =
        Bonfire.API.MastoCompat.Accounts.by_ids(ids, conn.assigns[:current_user], counts: true)

      accounts =
        ids
        |> Enum.map(&Map.get(by_id, &1))
        |> Enum.reject(&is_nil/1)
        |> Enum.map(&Mappers.Account.from_user/1)
        |> Enum.reject(&is_nil/1)

      RestAdapter.json(conn, accounts)
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

        notifying_ids = notifying_ids(current_user, ids)

        relationships =
          Enum.flat_map(ids, fn id ->
            case read_relationship(current_user, id, id in notifying_ids) do
              {:ok, relationship} -> [relationship]
              _ -> []
            end
          end)

        RestAdapter.json(conn, relationships)
      end
    end

    @doc """
    Get familiar followers for given account IDs.
    Returns accounts that the current user follows AND who also follow each target.
    Mastodon API: GET /api/v1/accounts/familiar_followers?id[]=1&id[]=2
    """
    @graphql "query ($ids: [ID!]!) {
      me {
        familiar_followers(ids: $ids) { id accounts { #{@account_fields} } }
      }
    }"
    def familiar_followers_gql(params, conn), do: graphql(conn, :familiar_followers_gql, params)

    def familiar_followers(params, conn) do
      current_user = conn.assigns[:current_user]

      if is_nil(current_user) do
        RestAdapter.error_fn({:error, :unauthorized}, conn)
      else
        target_ids =
          case params do
            %{"id" => ids} when is_list(ids) -> ids
            %{"id" => id} when is_binary(id) -> [id]
            _ -> []
          end

        case familiar_followers_gql(%{"ids" => target_ids}, conn) do
          %{data: %{me: %{familiar_followers: familiar}}} when is_list(familiar) ->
            RestAdapter.json(conn, Enum.map(familiar, &familiar_entry/1))

          other ->
            graphql_error(other, conn)
        end
      end
    end

    defp familiar_entry(%{id: id} = item) do
      %{
        "id" => id,
        "accounts" =>
          (item[:accounts] || [])
          |> Enum.map(&Mappers.Account.from_user/1)
          |> Enum.reject(&is_nil/1)
      }
    end

    @doc """
    Lookup an account by webfinger address.
    Mastodon API: GET /api/v1/accounts/lookup?acct=username or acct=username@domain
    """
    def lookup_account(%{"acct" => acct}, conn) when is_binary(acct) and acct != "" do
      user(%{"filter" => %{"username" => acct}}, conn)
    end

    def lookup_account(_params, conn), do: RestAdapter.error_fn({:error, :not_found}, conn)

    @doc """
    Search for accounts by username or display name.
    Mastodon API: GET /api/v1/accounts/search?q=query
    """
    @graphql "query ($query: String!, $limit: Int) {
      search_accounts(query: $query, limit: $limit) { #{@account_fields} }
    }"
    def search_accounts_gql(params, conn), do: graphql(conn, :search_accounts_gql, params)

    def search_accounts(params, conn) do
      query = params["q"] || ""
      limit = PaginationHelpers.validate_limit(params["limit"] || 10, max: 40)

      if String.trim(query) == "" do
        RestAdapter.json(conn, [])
      else
        search_accounts_gql(%{"query" => query, "limit" => limit}, conn)
        |> RestAdapter.return(:search_accounts, ..., conn, fn users ->
          users |> Enum.map(&Mappers.Account.from_user/1) |> Enum.reject(&is_nil/1)
        end)
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
    @graphql "query ($limit: Int) {
      me { suggestions(limit: $limit) { #{Fragments.author_fields()} } }
    }"
    def suggestions_gql(params, conn), do: graphql(conn, :suggestions_gql, params)

    def suggestions(params, conn) do
      suggested(params, conn, fn users ->
        Mappers.Suggestion.from_users(users, source: "staff", sources: ["featured"])
      end)
    end

    @doc "GET /api/v1/suggestions: the same query as v2, as plain accounts (Mastodon's v1 shape, masto-live-fixes step 3)."
    def suggestions_v1(params, conn) do
      suggested(params, conn, fn users ->
        users
        |> Enum.map(&Mappers.Account.from_user/1)
        |> Enum.reject(&is_nil/1)
      end)
    end

    # what both versions share: the guard, the limit and the query; `map_users` gives each its shape
    defp suggested(params, conn, map_users) do
      if is_nil(conn.assigns[:current_user]) do
        RestAdapter.error_fn({:error, :unauthorized}, conn)
      else
        limit = PaginationHelpers.validate_limit(params["limit"], default: 40, max: 80)

        suggestions_gql(%{"limit" => limit}, conn)
        |> RestAdapter.return(:me, ..., conn, fn me -> map_users.(me[:suggestions] || []) end)
      end
    end

    @doc """
    Create a new account via Mastodon API signup.

    Requires an app token (client credentials) in the Authorization header.
    Returns a user access token on success.
    """
    def signup(params, conn) do
      with {:ok, oauth_client} <- authorize_app_token(conn),
           {:ok, account_params, user_params} <- validate_signup_params(params),
           # Get first redirect_uri from OAuth client for deep-linking back to app after email confirmation
           redirect_uri <- List.first(oauth_client.redirect_uris || []),
           {:ok, account} <-
             Bonfire.Me.Accounts.signup(account_params,
               must_confirm?: true,
               redirect_uri: redirect_uri
             ),
           {:ok, user} <- Bonfire.Me.Users.create(user_params, account),
           {:ok, token} <- generate_user_token(user, oauth_client) do
        RestAdapter.json(conn, format_token_response(token))
      else
        {:error, :unauthorized} ->
          masto_error(conn, 401, "The access token is invalid")

        {:error, :missing_params, missing} ->
          masto_error(conn, 422, "Validation failed: #{Enum.join(missing, ", ")} required")

        {:error, :agreement_required} ->
          masto_error(conn, 422, "Validation failed: agreement must be accepted")

        # every invalid signup gets the same answer as any other failure, so the response doesn't tell whether an address has an account
        {:error, %Ecto.Changeset{} = changeset} ->
          debug(changeset, "Signup refused")
          masto_error(conn, 422, "Could not create account")

        # if email_taken?(changeset) do
        #   masto_error(conn, 422, "Could not create account")
        # else
        #   masto_error(
        #     conn,
        #     422,
        #     "Validation failed: #{Bonfire.Common.Errors.error_msg(changeset)}"
        #   )
        # end

        {:error, reason} ->
          error(reason, "Signup failed")
          masto_error(conn, 422, "Could not create account")

        :error ->
          masto_error(conn, 422, "Could not create account")
      end
    end

    # whether the changeset failed on the email address being already in use (a unique constraint error, whatever the language of its message)
    # defp email_taken?(%Ecto.Changeset{} = changeset) do
    #   changeset
    #   |> Ecto.Changeset.traverse_errors(fn {_msg, opts} -> opts[:constraint] end)
    #   |> get_in([:email, :email_address])
    #   |> List.wrap()
    #   |> Enum.member?(:unique)
    # end

    @doc """
    Resend confirmation email.

    Mastodon API: POST /api/v1/emails/confirmations

    Only works for the app that created the account (verified by token).
    Returns empty response on success.
    """
    def resend_confirmation(_params, conn) do
      current_user = conn.assigns[:current_user]

      if is_nil(current_user) do
        masto_error(conn, 401, "The access token is invalid")
      else
        with {:ok, account} <- get_user_account(current_user),
             true <- is_nil(account.email.confirmed_at) || {:error, :already_confirmed},
             {:ok, _, _} <-
               Bonfire.Me.Accounts.request_confirm_email(
                 %{email: account.email.email_address},
                 []
               ) do
          conn
          |> Plug.Conn.put_status(200)
          |> Phoenix.Controller.json(%{})
        else
          {:error, :already_confirmed} ->
            masto_error(
              conn,
              403,
              "This method is only available while the e-mail is awaiting confirmation"
            )

          _ ->
            masto_error(conn, 422, "Could not resend confirmation email")
        end
      end
    end

    defp masto_error(conn, status, message) do
      conn
      |> Plug.Conn.put_status(status)
      |> Phoenix.Controller.json(%{"error" => message})
    end

    defp get_user_account(user) do
      account_id = e(user, :account, :id, nil) || e(user, :accounted, :account_id, nil)

      with account_id when is_binary(account_id) <- account_id,
           {:ok, account} <-
             Bonfire.Me.Accounts.Queries.login_by_account_id(account_id)
             |> Bonfire.Common.Repo.single() do
        {:ok, account}
      else
        _ -> {:error, :account_not_found}
      end
    end

    defp authorize_app_token(conn) do
      with [authorization_header] <- Plug.Conn.get_req_header(conn, "authorization"),
           [_, bearer] <- Regex.run(~r/[B|b]earer (.+)/, authorization_header),
           {:ok, token} <- Boruta.Oauth.Authorization.AccessToken.authorize(value: bearer),
           %{id: _} = client <- token.client do
        {:ok, client}
      else
        _ -> {:error, :unauthorized}
      end
    end

    defp validate_signup_params(params) do
      required = ["username", "email", "password", "agreement"]
      missing = Enum.filter(required, &is_nil(params[&1]))

      cond do
        missing != [] ->
          {:error, :missing_params, missing}

        params["agreement"] not in [true, "true", "1"] ->
          {:error, :agreement_required}

        true ->
          account_params = %{
            email: %{email_address: params["email"]},
            credential: %{password: params["password"]}
          }

          user_params = %{
            profile: %{name: params["username"]},
            character: %{username: params["username"]}
          }

          {:ok, account_params, user_params}
      end
    end

    defp generate_user_token(user, oauth_client) do
      Boruta.Ecto.AccessTokens.create(
        %{client: oauth_client, sub: user.id, scope: "read write follow push"},
        refresh_token: true
      )
    end

    defp format_token_response(token) do
      base = %{
        "access_token" => token.value,
        "token_type" => "Bearer",
        "scope" => token.scope,
        "created_at" => System.system_time(:second)
      }

      if token.refresh_token,
        do: Map.put(base, "refresh_token", token.refresh_token),
        else: base
    end

    # Profile image deletion endpoints

    @doc "Delete the authenticated user's avatar. Mastodon API: DELETE /api/v1/profile/avatar"
    def delete_avatar(_params, conn), do: delete_profile_image(conn, :icon_id)

    @doc "Delete the authenticated user's header/banner. Mastodon API: DELETE /api/v1/profile/header"
    def delete_header(_params, conn), do: delete_profile_image(conn, :image_id)

    defp delete_profile_image(conn, field) do
      RestAdapter.with_current_user(conn, fn user ->
        with {:ok, updated} <- Bonfire.Me.Users.update(user, %{"profile" => %{field => nil}}) do
          own_account(conn, updated)
        else
          {:error, reason} -> RestAdapter.error_fn({:error, reason}, conn)
        end
      end)
    end

    @doc """
    Delete the authenticated user's account.
    Mastodon API: POST /api/v1/accounts/delete

    Requires password confirmation. Queues the account for async deletion.
    """
    def delete_account(%{"password" => password}, conn) when is_binary(password) do
      RestAdapter.with_current_user(conn, fn user ->
        # the password is the account's, which the user is only linked to by `accounted`
        user = Bonfire.Common.Repo.maybe_preload(user, :accounted)

        with true <- Bonfire.Me.Accounts.login_valid?(user, password),
             {:ok, _} <- Bonfire.Me.Users.enqueue_delete(user) do
          Plug.Conn.send_resp(conn, 200, "")
        else
          false -> RestAdapter.error_fn({:error, :forbidden}, conn)
          {:error, _} = error -> RestAdapter.error_fn(error, conn)
        end
      end)
    end

    def delete_account(_params, conn) do
      RestAdapter.error_fn({:error, "Password is required"}, conn)
    end

    @doc """
    Set up an account alias for migration.
    Mastodon API: POST /api/v1/accounts/alias

    Adds the specified account(s) to the alsoKnownAs field of the current user's
    ActivityPub actor. This is required before the target account can perform
    a Move activity.

    Params:
    - `also_known_as_uris`: Array of ActivityPub actor URIs
    """
    def alias_account(%{"also_known_as_uris" => uris}, conn) when is_list(uris) do
      RestAdapter.with_current_user(conn, fn user ->
        with :ok <- ensure_federation_enabled(),
             {:ok, actor} <- ActivityPub.Actor.get_cached(pointer: user.id),
             new_aliases <- merge_aliases(actor, uris),
             updated_data <- Map.put(actor.data, "alsoKnownAs", new_aliases),
             {:ok, _} <- ActivityPub.Actor.update_actor(actor.ap_id, updated_data, false, true) do
          own_account(conn, user)
        else
          {:error, reason} -> RestAdapter.error_fn({:error, reason}, conn)
        end
      end)
    end

    def alias_account(_params, conn) do
      RestAdapter.error_fn({:error, "also_known_as_uris parameter is required"}, conn)
    end

    @doc """
    Move the account to another account on a different instance.
    Mastodon API: POST /api/v1/accounts/move

    Params:
    - `moved_to_account`: The ActivityPub URI of the target account
    - `password`: Current password for verification

    Preconditions:
    - Target account must have this account in its alsoKnownAs field
    - Password verification required
    """
    def move_account(%{"moved_to_account" => target_uri, "password" => password}, conn)
        when is_binary(target_uri) and is_binary(password) do
      RestAdapter.with_current_user(conn, fn user ->
        with {:ok, _} <- Bonfire.Me.Accounts.login_valid?(user, password),
             :ok <- ensure_federation_enabled(),
             {:ok, origin_actor} <- ActivityPub.Actor.get_cached(pointer: user.id),
             {:ok, target_actor} <- ActivityPub.Actor.get_cached_or_fetch(ap_id: target_uri),
             {:ok, _} <- ActivityPub.move(origin_actor, target_actor, true) do
          own_account(conn, user)
        else
          {:error, :not_in_also_known_as} ->
            RestAdapter.error_fn(
              {:error, "Target account must list this account in alsoKnownAs"},
              conn
            )

          {:error, _} ->
            RestAdapter.error_fn({:error, :forbidden}, conn)
        end
      end)
    end

    def move_account(_params, conn) do
      RestAdapter.error_fn(
        {:error, "moved_to_account and password parameters are required"},
        conn
      )
    end

    # Helper functions

    # a GraphQL result that is not the data expected: its errors, or the error tuple `graphql/2` can return
    defp graphql_error({:error, _} = error, conn), do: RestAdapter.error_fn(error, conn)
    defp graphql_error(%{errors: errors}, conn), do: RestAdapter.error_fn({:error, errors}, conn)
    defp graphql_error(other, conn), do: RestAdapter.error_fn({:error, other}, conn)

    defp own_account_json(account, follow_requests_count, current_user) do
      account
      |> Map.put(:follow_requests_count, follow_requests_count)
      |> Map.put(:default_privacy, default_visibility(current_user))
      |> Mappers.Account.from_user(include_source: true)
    end

    defdelegate default_visibility(current_user), to: Bonfire.API.MastoCompat.Helpers

    @graphql "query ($filter: CharacterFilters) {
      me { follow_requests_count }
      user(filter: $filter) { #{@account_fields} }
    }"
    def own_account_gql(params, conn), do: graphql(conn, :own_account_gql, params)

    # read back by id after a change, so the change is seen
    defp own_account(conn, user) do
      case own_account_gql(%{"filter" => %{"id" => uid(user)}}, conn) do
        %{data: %{user: %{} = account} = data} ->
          RestAdapter.json(
            conn,
            own_account_json(account, get_in(data, [:me, :follow_requests_count]), user)
          )

        other ->
          graphql_error(other, conn)
      end
    end

    defp ensure_federation_enabled do
      if module_enabled?(ActivityPub.Actor), do: :ok, else: {:error, "Federation is not enabled"}
    end

    defp merge_aliases(actor, uris) do
      existing = e(actor, :data, "alsoKnownAs", []) || []
      Enum.uniq(existing ++ uris)
    end
  end
end
