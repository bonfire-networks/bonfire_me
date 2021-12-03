if Code.ensure_loaded?(Bonfire.GraphQL) do
defmodule Bonfire.Me.API.GraphQL do
  use Absinthe.Schema.Notation
  import Absinthe.Resolution.Helpers
  alias Bonfire.GraphQL

  object :user do
    field(:id, :string)
    field(:profile, :profile)
    field(:character, :character)

    field :posts, list_of(:post) do
      arg :paginate, :paginate # TODO

      resolve dataloader(Bonfire.Data.Identity.User)
    end

    field :user_activities, list_of(:activity) do
      arg :paginate, :paginate # TODO

      resolve dataloader(Bonfire.Data.Identity.User)
    end

    field :boost_activities, list_of(:activity) do
      arg :paginate, :paginate # TODO

      resolve dataloader(Bonfire.Data.Identity.User)
    end

  end

  object :me do
    # field(:current_account, :json)
    field(:user, :user) do
      resolve &get_user/3
    end

    field :user_feed, list_of(:activity) do
      arg :paginate, :paginate # TODO

      resolve &my_feed/3
    end

    field :like_activities, list_of(:activity) do
      arg :paginate, :paginate # TODO

      resolve dataloader(Bonfire.Data.Identity.User)
    end

    field :followers, list_of(:follow) do
      arg :paginate, :paginate # TODO

      resolve dataloader(Bonfire.Data.Identity.User, args: %{my: :followers})
    end

    field :followed, list_of(:follow) do
      arg :paginate, :paginate # TODO

      resolve dataloader(Bonfire.Data.Identity.User, args: %{my: :followed})
    end

  end

  object :profile do
    field(:name, :string)
    field(:summary, :string)
  end

  object :character do
    field(:username, :string)
  end

  input_object :character_filters do
    field(:id, :string)
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

  object :me_mutations do

  end

  def get_user(_parent, %{filter: %{username: username}}, info) do
    Bonfire.Me.Users.by_username(username)
  end

  def get_user(_parent, %{filter: %{id: id}}, info) do
    Bonfire.Me.Users.by_id(id)
  end

  def get_user(%Bonfire.Data.Identity.User{} = parent, args, info) do
    # IO.inspect(parent: parent)
    {:ok, parent}
  end

  def get_user(_parent, args, info) do
    # IO.inspect(args: args)
    {:ok, GraphQL.current_user(info)}
  end

  def get_user(_args, info) do
    {:ok, GraphQL.current_user(info)}
  end

  def my_feed(%Bonfire.Data.Identity.User{} = parent, args, info) do
    # IO.inspect(parent: parent)
    {:ok,
      Bonfire.Social.FeedActivities.my_feed(parent)
      |> Map.get(:entries) # TODO: handle pagination
      # |> IO.inspect()
      |> Enum.map(& Map.get(&1, :activity))
    }
  end

end
end
