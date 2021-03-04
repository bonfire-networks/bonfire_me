defmodule Bonfire.Me.Social.FeedActivities do

  alias Bonfire.Data.Social.{Feed, FeedPublish, Like, Boost}
  alias Bonfire.Data.Identity.{User}
  alias Bonfire.Me.Social.Feeds
  alias Bonfire.Me.Social.Activities
  alias Bonfire.Common.Utils

  use Bonfire.Repo.Query,
      schema: FeedPublish,
      searchable_fields: [:id, :feed_id, :object_id],
      sortable_fields: [:id]

  def my_feed(user, cursor_after \\ nil) do

    # feeds the user is following
    feed_ids = Feeds.my_feed_ids(user)
    # IO.inspect(inbox_feed_ids: feed_ids)

    feed(feed_ids, user, cursor_after)
  end

  def feed(%{id: feed_id}, current_user \\ nil, cursor_after \\ nil), do: feed(feed_id, current_user, cursor_after)

  def feed(feed_id_or_ids, current_user, cursor_after) when is_binary(feed_id_or_ids) or is_list(feed_id_or_ids) do

    Utils.pubsub_subscribe(feed_id_or_ids) # subscribe to realtime feed updates

    build_query(feed_id: feed_id_or_ids) # query FeedPublish + assocs needed in timelines/feeds
      |> Activities.activity_preloads(current_user)
      |> Bonfire.Repo.many_paginated(before: cursor_after) # return a page of items + pagination metadata
      # |> IO.inspect
  end

  def feed(_, _, _), do: []

  # def feed(%{feed_publishes: _} = feed_for, _) do
  #   repo().maybe_preload(feed_for, [feed_publishes: [activity: [:verb, :object, subject_user: [:profile, :character]]]]) |> Map.get(:feed_publishes)
  # end

  @doc """
  Creates a new local activity and publishes to appropriate feeds
  """
  def publish(subject, verb, object) when is_atom(verb) do
    do_publish(subject, verb, object, Feeds.instance_feed_id())
  end

  @doc """
  Records a remote activity and puts in appropriate feeds
  """
  def save_fediverse_incoming_activity(subject, verb, object) when is_atom(verb) do
    do_publish(subject, verb, object, Feeds.fediverse_feed_id())
  end

  @doc """
  Creates a new local activity and publishes to creator's inbox
  """
  def maybe_notify_creator(subject, verb, object) when is_atom(verb) do
    object = object |> Bonfire.Repo.maybe_preload([creator_character: [:inbox]]) |> IO.inspect

    inbox_feed_id = Utils.e(object, :creator_character, :inbox, :feed_id, nil)
                    || Feeds.inbox_feed_id(Utils.e(object, :creator_character, nil))

    do_notify(subject, verb, object, inbox_feed_id)
    # TODO: notify remote users via AP
  end

  defp do_notify(subject, verb, object, feed_id) when is_binary(feed_id) do
    with {:ok, activity} <- Activities.create(subject, verb, object),
    {:ok, published} <- feed_publish(feed_id, activity)
     do
      {:ok, published}
    end
  end

  defp do_publish(subject, verb, object, extra_feed) do
    with {:ok, activity} <- Activities.create(subject, verb, object),
    {:ok, published} <- feed_publish(subject, activity), # publish in user's timeline
    {:ok, _published} <- feed_publish(extra_feed, activity) # publish in local instance or fediverse feed
     do
      {:ok, published}
    end
  end

  defp feed_publish(feed_or_subject, activity) do
    with {:ok, %{id: feed_id} = feed} <- Feeds.feed_for_id(feed_or_subject),
    {:ok, published} <- do_feed_publish(feed, activity) do

      published = %{published | activity: activity}

      # Utils.pubsub_broadcast(feed.id, {:feed_activity, activity}) # push to online users
      Utils.pubsub_broadcast(feed_id, published) # push to online users

      {:ok, published}
    end
  end

  defp do_feed_publish(%{id: feed_id}, %{id: activity_or_object_id}) do
    attrs = %{feed_id: feed_id, object_id: activity_or_object_id}
    repo().put(FeedPublish.changeset(attrs))
  end

  @doc "Delete an activity (usage by things like unlike)"
  def delete_for_object(%{id: id}), do: delete_for_object(id)
  def delete_for_object(id) when is_binary(id) and id !="", do: build_query(object_id: id) |> repo().delete_all() |> elem(1)
  def delete_for_object(ids) when is_list(ids), do: Enum.each(ids, fn x -> delete_for_object(x) end)
  def delete_for_object(_), do: nil


end
