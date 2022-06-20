if Bonfire.Common.Extend.module_enabled?(Bonfire.API.GraphQL) and Code.ensure_loaded?(Absinthe.Schema.Notation) do
defmodule Bonfire.Me.API.GraphQL do
  import Where
  use Absinthe.Schema.Notation
  use Bonfire.Common.Utils
  alias Absinthe.Resolution.Helpers

  alias Bonfire.API.GraphQL
  alias Bonfire.Data.Identity.User
  alias Bonfire.Me.Users
  alias Bonfire.Me.Accounts

  import_types Absinthe.Plug.Types

  object :user do
    field(:id, :id)
    field(:profile, :profile)
    field(:character, :character)

    field(:is_instance_admin, :boolean) do
      resolve fn user, _, _ -> {:ok, Users.is_admin?(user)} end
    end

    field :posts, list_of(:post) do
      arg :paginate, :paginate # TODO

      resolve Absinthe.Resolution.Helpers.dataloader(Pointers.Pointer)
    end

    field :user_activities, list_of(:activity) do
      arg :paginate, :paginate # TODO

      resolve Absinthe.Resolution.Helpers.dataloader(Pointers.Pointer)
    end

    field :boost_activities, list_of(:activity) do
      arg :paginate, :paginate # TODO

      resolve Absinthe.Resolution.Helpers.dataloader(Pointers.Pointer)
    end

  end

  object :me do
    # field(:current_account, :json)
    field(:user, :user) do
      resolve &get_user/3
    end

    field(:account_id, :id) do
      resolve &account_id/3
    end

    field(:users, list_of(:user)) do
      resolve &account_users/3
    end

    field :user_feed, list_of(:activity) do
      arg :paginate, :paginate # TODO

      resolve &my_feed/3
    end

    field :user_notifications, list_of(:activity) do
      arg :paginate, :paginate # TODO

      resolve &my_notifications/3
    end

    field :flags_for_moderation, list_of(:activity) do
      arg :paginate, :paginate # TODO

      resolve &all_flags/3
    end

    field :like_activities, list_of(:activity) do
      arg :paginate, :paginate # TODO

      resolve Absinthe.Resolution.Helpers.dataloader(Pointers.Pointer)
    end

    field :followers, list_of(:activity) do
      arg :paginate, :paginate # TODO

      resolve Absinthe.Resolution.Helpers.dataloader(Pointers.Pointer)
    end

    field :followed, list_of(:activity) do
      arg :paginate, :paginate # TODO

      resolve Absinthe.Resolution.Helpers.dataloader(Pointers.Pointer)
    end

  end


  object :profile do
    field(:name, :string)
    field(:summary, :string)
    field :website, :string
    field :location, :string

    field(:icon, :string) do
      resolve &icon/3
    end
    field(:image, :string) do
      resolve &image/3
    end
  end

  input_object :profile_input do
    field(:name, :string)
    field(:summary, :string)
    field :website, :string
    field :location, :string
  end

  input_object :images_upload do
    field :icon, :upload
    field :image, :upload
  end

  object :character do
    field(:username, :string)
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

    @desc "Get a user"
    field :user, :user do
      arg :filter, :character_filters

      resolve &get_user/3
    end

    @desc "Get information about and for the current account and/or user"
    field :me, :me do

      resolve &get_me/3
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
      middleware(&Bonfire.API.GraphQL.Auth.set_context_from_resolution/2) # FIXME: this should auto-login
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
    {:ok, GraphQL.current_user(info) || GraphQL.current_account(info)}
  end

  defp my_feed(%{} = parent, _args, _info) do
    Bonfire.Social.FeedActivities.my_feed(parent)
    |> feed()
  end

  defp my_notifications(%User{} = user, _args, _info) do
    Bonfire.Social.FeedActivities.feed(:notifications, user)
    |> feed()
  end

  defp all_flags(%{} = user_or_account, _args, _info) do
    Bonfire.Social.Flags.list_paginated([], user_or_account)
    |> feed()
  end

  defp feed(%{edges: feed}) when is_list(feed) do
    {:ok,
      feed
      |> Enum.map(& Map.get(&1, :activity))
    }
  end
  defp feed(_), do: {:ok, nil}

  defp account_id(%{accounted: %{account_id: account_id}}, _, _) do
    {:ok, account_id}
  end
  defp account_id(_, _, %{context: %{current_account_id: current_account_id} = _context}) when is_binary(current_account_id) do
    {:ok, current_account_id}
  end
  defp account_id(_, _, _context) do
    {:ok, nil}
  end

  def account_users(_, _, info) do
    account = GraphQL.current_account(info)
    if account do
      with users when is_list(users) <- Utils.maybe_apply(Users, :by_account, account) do
        {:ok, users }
      end
    else
      {:error, "Not authenticated"}
    end
  end

  defp signup(args, _resolution) do
    params = %{
      email: %{email_address: args[:email]},
      credential: %{password: args[:password]}
    } #|> IO.inspect
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
            Bonfire.Me.Users.update(user, %{"profile"=> uploaded}) #|> debug("updated")
      end
    else
      {:error, "Account not authenticated"}
    end
  end

  defp confirm_email(%{token: token} = _args, _info) do
    with {:ok, account} <- Accounts.confirm_email(token) do
      {:ok, %{
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
      Accounts.change_password(account, Utils.stringify_keys(args))
    else
      {:error, "Not authenticated"}
    end
  end

  def update_user(args, info) do
    user = GraphQL.current_user(info) #|| (Users.by_username("test") |> ok_or)
    if user do
      with {:ok, uploaded} <- maybe_upload(user, args[:images], info) do
            args = args |> Map.put(:profile, Map.merge(Map.get(args, :profile, %{}), uploaded)) #|> debug("args") # TODO: clean up
            Bonfire.Me.Users.update(user, args, GraphQL.current_account(info)) #|> debug("updated")
      end
    else
      {:error, "Not authenticated"}
    end
  end

  defp add_team_member(%{username_or_email: username_or_email} = args, info) do
    if module_enabled?(Bonfire.Data.SharedUser) do
      user = GraphQL.current_user(info)
      if user do
        with %{} = _shared_user <- Bonfire.Me.SharedUsers.add_account(user, username_or_email, Utils.stringify_keys(args)) do
          :ok
        end
      else
        {:error, "Not authenticated"}
      end
    else
      {:error, "Feature not available (no SharedUsers module found)"}
    end
  end

  def icon(thing, _, _info) do
    {:ok, Bonfire.Common.Utils.avatar_url(thing)}
  end

  def image(thing, _, _info) do
    {:ok, Bonfire.Common.Utils.banner_url(thing)}
  end

  def maybe_upload(user, changes, info) do
    if module_enabled?(Bonfire.Files.GraphQL) do
      debug("API - attempt to upload")
      Bonfire.Files.GraphQL.upload(user, changes, info)
    else
      error("API upload via GraphQL is not implemented")
      {:ok, %{}}
    end
  end
end
end
