if Code.ensure_loaded?(Bonfire.GraphQL) do
defmodule Bonfire.Me.API.GraphQL do
  use Absinthe.Schema.Notation
  import Absinthe.Resolution.Helpers
  alias Bonfire.GraphQL
  alias Bonfire.Common.Utils
  alias Bonfire.Data.Identity.User
  alias Bonfire.Me.Users
  alias Bonfire.Me.Accounts

  object :user do
    field(:id, :id)
    field(:profile, :profile)
    field(:character, :character)

    field(:is_instance_admin, :boolean) do
      resolve fn user, _, _ -> {:ok, Users.is_admin?(user)} end
    end

    field :posts, list_of(:post) do
      arg :paginate, :paginate # TODO

      resolve dataloader(Pointers.Pointer)
    end

    field :user_activities, list_of(:activity) do
      arg :paginate, :paginate # TODO

      resolve dataloader(Pointers.Pointer)
    end

    # field :boost_activities, list_of(:activity) do
    #   arg :paginate, :paginate # TODO

    #   resolve dataloader(Pointers.Pointer)
    # end

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

      resolve dataloader(Pointers.Pointer)
    end

    field :followers, list_of(:follow) do
      arg :paginate, :paginate # TODO

      resolve dataloader(Pointers.Pointer, args: %{my: :followers})
    end

    field :followed, list_of(:follow) do
      arg :paginate, :paginate # TODO

      resolve dataloader(Pointers.Pointer, args: %{my: :followed})
    end

  end


  object :profile do
    field(:name, :string)
    field(:summary, :string)
  end
  input_object :profile_input do
    field(:name, :string)
    field(:summary, :string)
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
      middleware(&Bonfire.GraphQL.Auth.set_context_from_resolution/2) # FIXME: this should auto-login
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
      arg(:profile, non_null(:profile_input))
      # arg(:character, non_null(:character_input))

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

  defp get_user(_parent, %{filter: %{username: username}}, info) do
    Users.by_username(username)
  end

  defp get_user(_parent, %{filter: %{id: id}}, info) do
    Users.by_id(id)
  end

  defp get_user(%User{} = parent, args, info) do
    # IO.inspect(parent: parent)
    {:ok, parent}
  end

  defp get_user(_parent, args, info) do
    {:ok, GraphQL.current_user(info)}
  end

  defp get_me(_parent, _args, info) do
    {:ok, GraphQL.current_user(info) || GraphQL.current_account(info)}
  end

  defp my_feed(%{} = parent, args, _info) do
    Bonfire.Social.FeedActivities.my_feed(parent)
    |> feed()
  end

  defp my_notifications(%User{} = user, args, info) do
    Bonfire.Social.FeedActivities.feed(:notifications, user)
    |> feed()
  end

  defp all_flags(%{} = user_or_account, args, info) do
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
    defp account_id(_, _, %{context: %{current_account_id: current_account_id} = _context}) do
    {:ok, current_account_id}
  end
  defp account_id(_, _, %{context: %{current_account_id: current_account_id} = _context}) do
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
    if account do
      Users.create(args, account)
    else
      {:error, "Not authenticated"}
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

  def update_user(params, info) do
    user = GraphQL.current_user(info)
    if user do
      Users.update(user, params, GraphQL.current_account(info))
    else
      {:error, "Not authenticated"}
    end
  end

  defp add_team_member(%{username_or_email: username_or_email} = args, info) do
    if Utils.module_enabled?(Bonfire.Data.SharedUser) and Utils.module_enabled?(Bonfire.Me.SharedUsers) do
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


end
end
