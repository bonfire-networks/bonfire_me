defmodule Bonfire.Me.Social.Feeds do

  alias Bonfire.Data.Social.{Feed, FeedPublish}
  alias Bonfire.Data.Identity.{User}
  alias Bonfire.Me.Social.{Activities, Follows}
  alias Ecto.Changeset
  import Ecto.Query
  import Bonfire.Me.Integration
  alias Bonfire.Common.Utils

  def instance_feed_id, do: Bonfire.Me.Social.Circles.circles[:local]
  def fediverse_feed_id, do: Bonfire.Me.Social.Circles.circles[:activity_pub]

  def my_feed_ids(%{} = user, extra_feeds \\ []) do
    extra_feeds = extra_feeds ++ [user.id]
    with following_ids when is_list(following_ids) <- Follows.by_follower(user) do
      # IO.inspect(subs: following_ids)
      extra_feeds ++ following_ids
    else
      _e ->
        # IO.inspect(e: e)
        extra_feeds
    end
  end

  def my_feed_ids(_, extra_feeds), do: extra_feeds

  @doc """
  Create a feed for an existing Pointable (eg. User)
  """
  def create(%{id: id}=_thing) do
    do_create(%{id: id})
  end

  @doc """
  Create a new generic feed
  """
  def create() do
    do_create(%{})
  end

  defp do_create(attrs) do
    repo().put(changeset(attrs))
  end

  def changeset(activity \\ %Feed{}, %{} = attrs) do
    Feed.changeset(activity, attrs)
  end

  @doc """
  Get or create feed for something
  """
  def feed_for_id(%{id: subject_id}), do: feed_for_id(subject_id)
  def feed_for_id(subject_id) when is_binary(subject_id) do
    with {:error, _} <- repo().single(feed_for_id_query(subject_id)) do
      create(%{id: subject_id})
    end
  end

  def feed_for_id_query(subject_id) do
    from f in Feed,
     where: f.id == ^subject_id
  end


end
