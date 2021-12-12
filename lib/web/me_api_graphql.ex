if Code.ensure_loaded?(Bonfire.GraphQL) do
defmodule Bonfire.Me.API.GraphQL do
  use Absinthe.Schema.Notation
  import Absinthe.Resolution.Helpers
  alias Bonfire.GraphQL
  alias Bonfire.Common.Utils

  object :user do
    field(:id, :id)
    field(:profile, :profile)
    field(:character, :character)

    field :posts, list_of(:post) do
      arg :paginate, :paginate # TODO

      resolve dataloader(Pointers.Pointer)
    end

    field :user_activities, list_of(:activity) do
      arg :paginate, :paginate # TODO

      resolve dataloader(Pointers.Pointer)
    end

    field :boost_activities, list_of(:activity) do
      arg :paginate, :paginate # TODO

      resolve dataloader(Pointers.Pointer)
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


  object :account_only do
    field(:account_id, :string) do
      resolve &account_id/3
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

    @desc "Get information about and for the current user"
    field :me, :me do

      resolve &get_user/2
    end

  end

  # input_object :an_input do
  #     arg(:email_or_username, non_null(:string))
  #     arg(:password, non_null(:string))
  # end

  object :me_mutations do

    field :signup, :account_only do
      arg(:email, non_null(:string))
      arg(:password, non_null(:string))

      arg(:invite_code, :string)

      resolve(&signup/2)
    end

    field :create_user, :me do
      arg(:profile, non_null(:profile_input))
      arg(:character, non_null(:character_input))

      resolve(&create_user/2)
    end

  end

  defp get_user(_parent, %{filter: %{username: username}}, info) do
    Bonfire.Me.Users.by_username(username)
  end

  defp get_user(_parent, %{filter: %{id: id}}, info) do
    Bonfire.Me.Users.by_id(id)
  end

  defp get_user(%Bonfire.Data.Identity.User{} = parent, args, info) do
    # IO.inspect(parent: parent)
    {:ok, parent}
  end

  defp get_user(_parent, args, info) do
    # IO.inspect(args: args)
    {:ok, GraphQL.current_user(info)}
  end

  defp get_user(_args, info) do
    {:ok, GraphQL.current_user(info)}
  end

  defp my_feed(%Bonfire.Data.Identity.User{} = parent, args, info) do
    Bonfire.Social.FeedActivities.my_feed(parent)
    |> feed()
  end

  defp my_notifications(%Bonfire.Data.Identity.User{} = parent, args, info) do
    Bonfire.Social.FeedActivities.feed(:notifications, parent)
    |> feed()
  end

  defp all_flags(%Bonfire.Data.Identity.User{} = parent, args, info) do
    Bonfire.Social.Flags.list(parent)
    |> feed()
  end

  defp feed(%{edges: feed}) when is_list(feed) do
    {:ok,
      feed
      |> Enum.map(& Map.get(&1, :activity))
    }
  end

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
      with users when is_list(users) <- Utils.maybe_apply(Bonfire.Me.Users, :by_account, account) do
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
    Bonfire.Me.Accounts.signup(params, invite: args[:invite_code])
  end

  defp create_user(args, info) do
    account = GraphQL.current_account(info)
    if account do
      Bonfire.Me.Users.create(args, account)
    else
      {:error, "Not authenticated"}
    end
  end

end
end
