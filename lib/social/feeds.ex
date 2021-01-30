defmodule Bonfire.Me.Social.Feeds do

  alias Bonfire.Data.Social.{Feed}
  alias Bonfire.Data.Identity.{User}
  alias Bonfire.Me.Social.Activities
  alias Ecto.Changeset
  import Ecto.Query

  import Bonfire.Me.Integration

  @doc """
  Creates an activity and publishes it to appropriate feeds
  """
  def publish(subject, verb, object) when is_atom(verb) do
    with {:ok, activity} = Activities.create(subject, verb, object),
    {:ok, feed} <- feed_for(subject),
    {:ok, published} <- feed_publish(feed, activity)
     do
      {:ok, activity}
    end
  end

  defp feed_publish(%{id: feed_id}, %{id: object_id}) do
    attrs = %{feed_id: feed_id, object_id: object_id}
    repo().put(Bonfire.Data.Social.FeedPublish.changeset(attrs))
  end

  def create_outbox(%{id: character_id}=_character) do
    attrs = %{id: character_id}
    create(attrs)
  end

  defp create(attrs)do
    repo().put(changeset(attrs))
  end

  def changeset(activity \\ %Feed{}, %{} = attrs) do
    Feed.changeset(activity, attrs)
  end


  @doc """
  Get or create feed for a user or other subject
  """
  def feed_for(%{id: subject_id}), do: feed_for(subject_id)
  def feed_for(subject_id) when is_binary(subject_id) do
    with {:error, _} <- repo().single(feed_for_query(subject_id)) do
      create_outbox(%{id: subject_id})
    end
  end

  def feed_for_query(subject_id) do
    from f in Feed,
     where: f.id == ^subject_id
  end


end
