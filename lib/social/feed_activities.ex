defmodule Bonfire.Me.Social.FeedActivities do

  alias Bonfire.Data.Social.{Feed, FeedPublish}
  alias Bonfire.Data.Identity.{User}
  alias Bonfire.Me.Social.Feeds
  alias Bonfire.Me.Social.Activities
  alias Bonfire.Common.Utils

  use Bonfire.Repo.Query,
      schema: FeedPublish,
      searchable_fields: [:id, :feed_id, :verb],
      sortable_fields: [:id]

  def feed(%{id: feed_id}, cursor_after \\ nil), do: feed(feed_id, cursor_after)
  def feed(feed_id, cursor_after) when is_binary(feed_id) do
    build_query(feed_id: feed_id)
      |> preload_join(:activity)
      |> preload_join(:activity, :verb)
      |> preload_join(:activity, :object)
      |> preload_join(:activity, :object_post)
      |> preload_join(:activity, :object_post, :post_content)
      |> preload_join(:activity, :reply_to)
      |> preload_join(:activity, :subject_profile)
      |> preload_join(:activity, :subject_character)
      |> Bonfire.Repo.many_paginated(before: cursor_after)
  end

  def live_more(feed_id, %{"after" => cursor_after}, socket) do
    feed = Bonfire.Me.Social.FeedActivities.feed(feed_id, cursor_after)
    # IO.inspect(feed_pagination: feed)
    {:noreply,
      socket
      |> Phoenix.LiveView.assign(
        feed: socket.assigns.feed ++ Utils.e(feed, :entries, []),
        page_info: Utils.e(feed, :metadata, [])
      )}
  end

  # def feed(%{feed_publishes: _} = feed_for, _) do
  #   repo().maybe_preload(feed_for, [feed_publishes: [activity: [:verb, :object, subject_user: [:profile, :character]]]]) |> Map.get(:feed_publishes)
  # end

  @doc """
  Creates a new local activity and publishes to appropriate feeds
  """
  def publish(subject, verb, object) when is_atom(verb) do
    with {:ok, activity} = Activities.create(subject, verb, object),
    {:ok, _published} <- Feeds.feed_for_id(subject) |> Utils.ok() |> feed_publish(activity), # publish in user's feed
    {:ok, _published} <- Feeds.instance_feed_id() |> Feeds.feed_for_id() |> Utils.ok() |> feed_publish(activity) # publish in local timeline feed
    # TODO: publish to ActivityPub
     do
      {:ok, activity}
    end
  end

  @doc """
  Records a remote activity and puts in appropriate feeds
  """
  def save_fediverse_incoming_activity(subject, verb, object) when is_atom(verb) do
    with {:ok, activity} = Activities.create(subject, verb, object),
    {:ok, _published} <- Feeds.feed_for_id(subject) |> Utils.ok() |> feed_publish(activity), # publish in user's feed
    {:ok, _published} <- Feeds.fediverse_feed_id() |> Feeds.feed_for_id() |> Utils.ok() |> feed_publish(activity) # publish in fediverse feed
     do
      {:ok, activity}
    end
  end

  defp feed_publish(%{id: feed_id}, %{id: object_id}) do
    attrs = %{feed_id: feed_id, object_id: object_id}
    repo().put(FeedPublish.changeset(attrs))
  end

end
