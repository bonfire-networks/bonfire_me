if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled and
     Code.ensure_loaded?(Absinthe.Schema.Notation) do
  defmodule Bonfire.Me.API.GraphQL do
    @moduledoc "Account/User related API fields/endpoints for GraphQL"
    import Untangle
    use Absinthe.Schema.Notation
    use Absinthe.Relay.Schema.Notation, :modern
    use Bonfire.Common.Utils
    alias Absinthe.Resolution.Helpers

    alias Bonfire.API.GraphQL
    alias Bonfire.Data.Identity.User
    alias Bonfire.Me.Users
    alias Bonfire.Me.Accounts

    import_types(Absinthe.Plug.Types)

    object :user do
      field(:id, :id)

      field(:profile, :profile) do
        resolve(&resolve_profile/3)
      end

      field(:character, :character) do
        resolve(&resolve_character/3)
      end

      field(:date_created, :datetime) do
        resolve(fn %{id: id}, _, _ ->
          {:ok, Bonfire.Common.DatesTimes.date_from_pointer(id)}
        end)
      end

      # field(:is_instance_admin, :boolean) do
      #   resolve(fn user, _, _ -> {:ok, Bonfire.Me.Accounts.is_admin?(user)} end)
      # end

      field :posts, list_of(:post) do
        # TODO
        arg(:paginate, :paginate)

        resolve(Absinthe.Resolution.Helpers.dataloader(Needle.Pointer))
        # resolve(&Bonfire.Common.Needles.maybe_resolve(:posts, &1, &2, &2))
      end

      field :user_activities, list_of(:activity) do
        # TODO
        arg(:paginate, :paginate)

        resolve(Absinthe.Resolution.Helpers.dataloader(Needle.Pointer))
      end

      field :boost_activities, list_of(:activity) do
        # TODO
        arg(:paginate, :paginate)

        resolve(Absinthe.Resolution.Helpers.dataloader(Needle.Pointer))
      end

      # User stats for Mastodon API compatibility
      field :followers_count, :integer do
        resolve(&resolve_followers_count/3)
      end

      field :following_count, :integer do
        resolve(&resolve_following_count/3)
      end

      field :statuses_count, :integer do
        resolve(&resolve_statuses_count/3)
      end
    end

    object :me do
      # field(:current_account, :json)
      field(:user, :user) do
        resolve(fn
          %Bonfire.Data.Identity.User{} = user, _, _ ->
            {:ok, user}

          other, _, _ ->
            e =
              l(
                "No user profile found, you may need to first authenticate with a username instead of an email address, or select a user profile to indicate which one to use."
              )

            error(other, e <> " NOTE: You can use the selectUser API mutation.")
            raise e
        end)
      end

      field(:account_id, :id) do
        resolve(&account_id/3)
      end

      field(:users, list_of(:user)) do
        resolve(&account_users/3)
      end

      connection field :my_feed, node_type: :activity do
        # field :my_feed, list_of(:activity) do
        # resolve(&Bonfire.Social.API.GraphQL.my_feed/3)
        resolve(fn _parent, args, info ->
          maybe_apply(Bonfire.Social.API.GraphQL, :feed, [:my, args, info])
        end)
      end

      connection field :notifications, node_type: :activity do
        # field :user_notifications, list_of(:activity) do
        # resolve(&Bonfire.Social.API.GraphQL.my_notifications/3)
        resolve(fn _parent, args, info ->
          maybe_apply(Bonfire.Social.API.GraphQL, :feed, [:notifications, args, info])
        end)
      end

      connection field :flags, node_type: :activity do
        # field :flags_for_moderation, list_of(:activity) do
        # resolve(&Bonfire.Social.API.GraphQL.all_flags/3)
        resolve(fn _parent, args, info ->
          maybe_apply(Bonfire.Social.API.GraphQL, :feed, [:flags, args, info])
        end)
      end

      field :like_activities, list_of(:activity) do
        # TODO
        arg(:paginate, :paginate)

        resolve(Absinthe.Resolution.Helpers.dataloader(Needle.Pointer))
      end

      field :followers, list_of(:activity) do
        # TODO
        arg(:paginate, :paginate)

        resolve(Absinthe.Resolution.Helpers.dataloader(Needle.Pointer))
      end

      field :followed, list_of(:activity) do
        # TODO
        arg(:paginate, :paginate)

        resolve(Absinthe.Resolution.Helpers.dataloader(Needle.Pointer))
      end
    end

    object :profile do
      field(:name, :string)
      field(:summary, :string)
      field(:website, :string)
      field(:location, :string)

      field(:icon, :string) do
        resolve(&icon/3)
      end

      field(:image, :string) do
        resolve(&image/3)
      end
    end

    input_object :profile_input do
      field(:name, :string)
      field(:summary, :string)
      field(:website, :string)
      field(:location, :string)
    end

    input_object :images_upload do
      field(:icon, :upload)
      field(:image, :upload)
    end

    object :peered do
      field(:id, :id)
      field(:canonical_uri, :string)
      field(:peer_id, :id)
    end

    object :created do
      field(:id, :id)
      field(:creator_id, :id)

      field :creator, :any_character do
        resolve(Absinthe.Resolution.Helpers.dataloader(Needle.Pointer, :creator))
      end
    end

    object :character do
      field(:username, :string)

      field(:peered, :peered) do
        resolve(Absinthe.Resolution.Helpers.dataloader(Needle.Pointer))
      end

      field(:canonical_uri, :string) do
        resolve(fn character, _, _ ->
          # Use preload_if_needed: false to rely on Dataloader batching
          {:ok, Bonfire.Common.URIs.canonical_url(character, preload_if_needed: false)}
        end)
      end
    end

    input_object :character_input do
      field(:username, :string)
    end

    input_object :character_filters do
      field(:id, :id)
      field(:username, :string)
      field(:autocomplete, :string)
    end

    object :me_queries do
      @desc "Get or lookup a user"
      field :user, :user do
        arg(:filter, :character_filters)

        resolve(&get_user/3)
      end

      @desc "List or lookup users"
      field :users, list_of(:user) do
        # TODO: lookup by filters
        # arg(:filter, :character_filters)

        resolve(&list_users/3)
      end

      @desc "Get information about and for the current account and/or user"
      field :me, :me do
        resolve(&get_me/3)
      end
    end

    # input_object :an_input do
    #     arg(:email_or_username, non_null(:string))
    #     arg(:password, non_null(:string))
    # end

    object :me_mutations do
      @desc "Register a new account. Returns the created `account_id`"
      field :signup, :string do
        arg(:email, non_null(:string))
        arg(:password, non_null(:string))

        arg(:invite_code, :string)

        resolve(&signup/2)
      end

      @desc "Request a new user identity for the authenticated account"
      field :create_user, :me do
        arg(:profile, non_null(:profile_input))
        arg(:character, non_null(:character_input))
        arg(:images, :images_upload)

        resolve(&create_user/2)
      end

      @desc "Request a new confirmation email"
      field :request_confirm_email, :string do
        arg(:email, non_null(:string))

        resolve(&request_confirm_email/2)
      end

      @desc "Confirm email address using a token generated upon `signup` or with `request_confirm_email` and emailed to the user."
      field :confirm_email, :me do
        arg(:token, non_null(:string))

        resolve(&confirm_email/2)
        # FIXME: this should auto-login
        middleware(&Bonfire.API.GraphQL.Auth.set_context_from_resolution/2)
      end

      @desc "Request an email to be sent to reset a forgotten password"
      field :request_reset_password, :string do
        arg(:email, non_null(:string))

        resolve(&request_forgot_password/2)
      end

      @desc "Change account password"
      field :change_password, :me do
        arg(:old_password, non_null(:string))
        arg(:password, non_null(:string))
        arg(:password_confirmation, non_null(:string))

        resolve(&change_password/2)
      end

      @desc "Edit user profile"
      field :update_user, :me do
        arg(:profile, :profile_input)
        # arg(:character, non_null(:character_input))
        arg(:images, :images_upload)

        resolve(&update_user/2)
      end

      @desc "Share the current user identity with a team member. This will give them full access to the currently authenticated user identity. Warning: anyone you add will have full access over this user identity, meaning they can post as this user, read private messages, etc."
      field :add_team_member, :string do
        @desc "Who to add (they need to be an existing user on this instance)"
        arg(:username_or_email, non_null(:string))

        @desc "What to call this team (eg. Organisation, Team, etc)"
        arg(:label, non_null(:string))

        resolve(&add_team_member/2)
      end
    end

    defp list_users(_, filters, info) do
      # TODO: pagination
      # Bonfire.Me.Users.list_paginated(
      #    current_user: current_user,
      #    paginate: paginate
      #  )
      # TODO: check if viewing directory is allowed
      {:ok, Bonfire.Me.Users.list(current_user: GraphQL.current_user(info))}
    end

    defp get_user(_parent, %{filter: %{username: username}}, _info) do
      Users.by_username(username)
    end

    defp get_user(_parent, %{filter: %{id: id}}, _info) do
      Users.by_id(id)
    end

    defp get_user(%User{} = parent, _args, _info) do
      # debug(parent: parent)
      {:ok, parent}
    end

    defp get_user(_parent, _args, info) do
      {:ok, GraphQL.current_user(info)}
    end

    defp get_me(_parent, _args, info) do
      # dump(info)
      case GraphQL.current_user(info) || GraphQL.current_account(info) do
        nil ->
          raise(Bonfire.Fail.Auth, :needs_login)

        # {:error, :needs_login}
        me ->
          {:ok, me}
      end
    end

    defp account_id(%{accounted: %{account_id: account_id}}, _, _) do
      {:ok, account_id}
    end

    defp account_id(_, _, %{
           context: %{current_account_id: current_account_id} = _context
         })
         when is_binary(current_account_id) do
      {:ok, current_account_id}
    end

    defp account_id(_, _, _context) do
      {:ok, nil}
    end

    def account_users(_, _, info) do
      account = GraphQL.current_account(info)

      if account do
        with users when is_list(users) <-
               Utils.maybe_apply(Users, :by_account, account) do
          {:ok, users}
        end
      else
        {:error, "Not authenticated"}
      end
    end

    defp signup(args, _resolution) do
      params = %{
        email: %{email_address: args[:email]},
        credential: %{password: args[:password]}
      }

      # |> IO.inspect
      with {:ok, account} <- Accounts.signup(params, invite: args[:invite_code]) do
        {:ok, Map.get(account, :id)}
      end
    end

    defp create_user(args, info) do
      account = GraphQL.current_account(info)
      # || Accounts.get_by_email("test@me.space") # only for testing
      if account do
        with {:ok, user} <- Users.create(args, account),
             {:ok, uploaded} <- maybe_upload(user, args[:images], info) do
          # |> debug("updated")
          Bonfire.Me.Users.update(user, %{"profile" => uploaded})
        end
      else
        {:error, "Account not authenticated"}
      end
    end

    defp confirm_email(%{token: token} = _args, _info) do
      with {:ok, account} <- Accounts.confirm_email(token) do
        {:ok,
         %{
           current_account: account,
           current_account_id: Map.get(account, :id)
         }}
      end
    end

    defp request_confirm_email(args, _info) do
      with {:ok, status, _} <- Accounts.request_confirm_email(args) do
        {:ok, status}
      end
    end

    defp request_forgot_password(args, _info) do
      with {:ok, status, _} <- Accounts.request_forgot_password(args) do
        {:ok, status}
      end
    end

    defp change_password(args, info) do
      account = GraphQL.current_account(info)

      if account do
        Accounts.change_password(account, Enums.stringify_keys(args, true))
      else
        {:error, "Not authenticated"}
      end
    end

    def update_user(args, info) do
      # || (Users.by_username("test") |> from_ok)
      user = GraphQL.current_user(info)

      if user do
        with {:ok, uploaded} <- maybe_upload(user, args[:images], info) do
          # |> debug("args") # TODO: clean up
          args =
            Map.put(
              args,
              :profile,
              Map.merge(Map.get(args, :profile, %{}), uploaded)
            )

          # |> debug("updated")
          Bonfire.Me.Users.update(user, args, GraphQL.current_account(info))
        end
      else
        {:error, "Not authenticated"}
      end
    end

    defp add_team_member(%{username_or_email: username_or_email} = args, info) do
      user = GraphQL.current_user(info)

      if module = maybe_module(Bonfire.Me.SharedUsers, user) do
        if user do
          with %{} = _shared_user <-
                 module.add_account(
                   user,
                   username_or_email,
                   Enums.stringify_keys(args, true)
                 ) do
            :ok
          end
        else
          {:error, "Not authenticated"}
        end
      else
        {:error, "Feature not available (no SharedUsers module found)"}
      end
    end

    # Resolve profile - handles preloaded data or falls back to Dataloader
    defp resolve_profile(%{profile: %Ecto.Association.NotLoaded{}} = parent, _args, %{
           context: %{loader: loader}
         }) do
      loader
      |> Dataloader.load(Needle.Pointer, :profile, parent)
      |> Helpers.on_load(fn loader ->
        {:ok, Dataloader.get(loader, Needle.Pointer, :profile, parent)}
      end)
    end

    defp resolve_profile(%{profile: profile}, _args, _info)
         when not is_struct(profile, Ecto.Association.NotLoaded) do
      {:ok, profile}
    end

    defp resolve_profile(parent, _args, %{context: %{loader: loader}}) do
      loader
      |> Dataloader.load(Needle.Pointer, :profile, parent)
      |> Helpers.on_load(fn loader ->
        {:ok, Dataloader.get(loader, Needle.Pointer, :profile, parent)}
      end)
    end

    defp resolve_profile(%{id: id}, _args, _info) do
      case Bonfire.Me.Users.by_id(id) do
        {:ok, user} -> {:ok, Map.get(user, :profile)}
        _ -> {:ok, nil}
      end
    end

    defp resolve_profile(_, _, _), do: {:ok, nil}

    # Resolve character - handles preloaded data or falls back to Dataloader
    defp resolve_character(%{character: %Ecto.Association.NotLoaded{}} = parent, _args, %{
           context: %{loader: loader}
         }) do
      loader
      |> Dataloader.load(Needle.Pointer, :character, parent)
      |> Helpers.on_load(fn loader ->
        {:ok, Dataloader.get(loader, Needle.Pointer, :character, parent)}
      end)
    end

    defp resolve_character(%{character: character}, _args, _info)
         when not is_struct(character, Ecto.Association.NotLoaded) do
      {:ok, character}
    end

    defp resolve_character(parent, _args, %{context: %{loader: loader}}) do
      loader
      |> Dataloader.load(Needle.Pointer, :character, parent)
      |> Helpers.on_load(fn loader ->
        {:ok, Dataloader.get(loader, Needle.Pointer, :character, parent)}
      end)
    end

    defp resolve_character(%{id: id}, _args, _info) do
      case Bonfire.Me.Users.by_id(id) do
        {:ok, user} -> {:ok, Map.get(user, :character)}
        _ -> {:ok, nil}
      end
    end

    defp resolve_character(_, _, _), do: {:ok, nil}

    # User stats resolvers using Dataloader for EdgeTotal counts
    defp resolve_followers_count(user, _args, %{context: %{loader: loader}}) do
      loader
      |> Dataloader.load(Needle.Pointer, :follow_count, user)
      |> Helpers.on_load(fn loader ->
        case Dataloader.get(loader, Needle.Pointer, :follow_count, user) do
          %{object_count: count} when is_integer(count) -> {:ok, count}
          _ -> {:ok, 0}
        end
      end)
    end

    defp resolve_followers_count(_user, _args, _info), do: {:ok, 0}

    defp resolve_following_count(user, _args, %{context: %{loader: loader}}) do
      loader
      |> Dataloader.load(Needle.Pointer, :follow_count, user)
      |> Helpers.on_load(fn loader ->
        case Dataloader.get(loader, Needle.Pointer, :follow_count, user) do
          %{subject_count: count} when is_integer(count) -> {:ok, count}
          _ -> {:ok, 0}
        end
      end)
    end

    defp resolve_following_count(_user, _args, _info), do: {:ok, 0}

    defp resolve_statuses_count(user, _args, _info) do
      # Count posts created by this user
      # TODO: Could be optimized with EdgeTotal in the future for better performance
      user_id = Bonfire.Common.Types.uid(user)

      count =
        if user_id do
          import Ecto.Query

          Bonfire.Common.Repo.one(
            from(c in Bonfire.Data.Social.Created,
              join: p in Bonfire.Data.Social.Post,
              on: c.id == p.id,
              where: c.creator_id == ^user_id,
              select: count(c.id)
            )
          ) || 0
        else
          0
        end

      {:ok, count}
    end

    # Use Dataloader to batch-load icon media and prevent N+1 queries
    def icon(parent, _args, %{context: %{loader: loader}}) do
      loader
      |> Dataloader.load(Needle.Pointer, :icon, parent)
      |> Helpers.on_load(fn loader ->
        case Dataloader.get(loader, Needle.Pointer, :icon, parent) do
          nil -> {:ok, nil}
          %Ecto.Association.NotLoaded{} -> {:ok, nil}
          media -> {:ok, Bonfire.Common.Media.avatar_url(media) |> URIs.based_url()}
        end
      end)
    end

    # Fallback for non-GraphQL contexts
    def icon(thing, _, _info) do
      {:ok, Bonfire.Common.Media.avatar_url(thing) |> URIs.based_url()}
    end

    # Use Dataloader to batch-load image media and prevent N+1 queries
    def image(parent, _args, %{context: %{loader: loader}}) do
      loader
      |> Dataloader.load(Needle.Pointer, :image, parent)
      |> Helpers.on_load(fn loader ->
        case Dataloader.get(loader, Needle.Pointer, :image, parent) do
          nil -> {:ok, nil}
          %Ecto.Association.NotLoaded{} -> {:ok, nil}
          media -> {:ok, Bonfire.Common.Media.banner_url(media) |> URIs.based_url()}
        end
      end)
    end

    # Fallback for non-GraphQL contexts
    def image(thing, _, _info) do
      {:ok, Bonfire.Common.Media.banner_url(thing) |> URIs.based_url()}
    end

    def maybe_upload(user, changes, info) do
      if module = maybe_module(Bonfire.Files.GraphQL, user) do
        debug("API - attempt to upload")
        module.upload(user, changes, info)
      else
        error("API upload via GraphQL is not implemented")
        {:ok, %{}}
      end
    end
  end
end
