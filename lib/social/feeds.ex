defmodule Bonfire.Me.Social.Feeds do

  alias Bonfire.Data.Social.{Feed, FeedPublish}
  alias Bonfire.Data.Identity.{User}
  alias Bonfire.Me.Social.Activities
  alias Ecto.Changeset
  import Ecto.Query
  import Bonfire.Me.Integration

  def instance_feed_id, do: Bonfire.Me.Social.Circles.circles[:local]
  def fediverse_feed_id, do: Bonfire.Me.Social.Circles.circles[:activity_pub]

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
  def feed_for_id(%{id: subject_id}), do: feed_for_id(subject_id)
  def feed_for_id(subject_id) when is_binary(subject_id) do
    with {:error, _} <- repo().single(feed_for_id_query(subject_id)) do
      create_outbox(%{id: subject_id})
    end
  end

  def feed_for_id_query(subject_id) do
    from f in Feed,
     where: f.id == ^subject_id
  end


end
