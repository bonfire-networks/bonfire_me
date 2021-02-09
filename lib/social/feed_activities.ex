defmodule Bonfire.Me.Social.FeedActivities do

  alias Bonfire.Data.Social.{Feed, FeedPublish}
  alias Bonfire.Data.Identity.{User}
  alias Bonfire.Me.Social.Activities

  use Bonfire.Repo.Query,
      schema: FeedPublish,
      searchable_fields: [:id, :feed_id, :verb],
      sortable_fields: [:id]

  def feed(%{id: feed_for_id}, cursor_after \\ nil) do
    build_query(feed_id: feed_for_id)
      |> preload_join(:activity)
      |> preload_join(:activity, :verb)
      |> preload_join(:activity, :object)
      |> preload_join(:activity, :object_post)
      |> preload_join(:activity, :object_post, :post_content)
      |> preload_join(:activity, :subject_user)
      |> preload_join(:activity, :subject_user, :profile)
      |> preload_join(:activity, :subject_user, :character)
      |> Bonfire.Repo.many_paginated(after: cursor_after)
  end

  def feed(%{feed_publishes: _} = feed_for, _) do
    repo().maybe_preload(feed_for, [feed_publishes: [activity: [:verb, :object, subject_user: [:profile, :character]]]]) |> Map.get(:feed_publishes)
  end


end
