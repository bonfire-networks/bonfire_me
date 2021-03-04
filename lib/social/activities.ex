defmodule Bonfire.Me.Social.Activities do

  alias Bonfire.Data.Social.{Activity, Like, Boost, Flag}
  alias Bonfire.Data.Identity.{User}
  alias Bonfire.Me.AccessControl.Verbs
  alias Ecto.Changeset
  # import Bonfire.Me.Integration
  # import Ecto.Query
  use Bonfire.Repo.Query,
    schema: Activity,
    searchable_fields: [:id, :subject_id, :verb_id, :object_id],
    sortable_fields: [:id, :subject_id, :verb_id, :object_id]

  @doc """
  Create an Activity
  NOTE: you will usually want to use `FeedActivities.publish/3` instead
  """
  def create(%{id: subject_id}=subject, verb, %{id: object_id}=object) when is_atom(verb) do

    verb_id = Verbs.verbs()[verb]

    attrs = %{subject_id: subject_id, verb_id: verb_id, object_id: object_id}

    with {:ok, activity} <- repo().put(changeset(attrs)) do
       {:ok, %{activity | object: object, subject: subject, subject_profile: Map.get(subject, :profile), subject_character: Map.get(subject, :character)}}
    end
  end

  def changeset(activity \\ %Activity{}, %{} = attrs) do
    Activity.changeset(activity, attrs)
  end

  @doc "Delete an activity (usage by things like unlike)"
  def delete_by_subject_verb_object(%{}=subject, verb, %{}=object) do
    q = by_subject_verb_object_q(subject, Verbs.verbs()[verb], object)
    Bonfire.Me.Social.FeedActivities.delete_for_object(repo.all(q)) # TODO: see why cascading delete doesn't take care of this
    elem(repo().delete_all(q), 1)
  end

  def by_subject_verb_object_q(%{id: subject}, verb, %{id: object}), do: by_subject_verb_object_q(subject, verb, object)

  def by_subject_verb_object_q(subject, verb, object) when is_binary(subject) and is_binary(object) do
    from f in Activity,
      where: f.subject_id == ^subject and f.object_id == ^object and f.verb_id == ^verb,
      select: f.id
  end


  def activity_preloads(query, current_user) do

    query
      |> preload_join(:activity)
      |> preload_join(:activity, :verb)
      # |> preload_join(:activity, :object)
      |> preload_join(:activity, :object_post_content)
      # |> preload_join(:activity, :object_post, :post_content)
      |> preload_join(:activity, :object_creator_profile)
      |> preload_join(:activity, :object_creator_character)
      # |> preload_join(:activity, :reply_to)
      |> preload_join(:activity, :reply_to_post_content)
      |> preload_join(:activity, :reply_to_creator_profile)
      |> preload_join(:activity, :reply_to_creator_character)
      |> preload_join(:activity, :subject_profile)
      |> preload_join(:activity, :subject_character)
      |> maybe_my_like(current_user)
      |> maybe_my_boost(current_user)
      |> maybe_my_flag(current_user)
      # |> IO.inspect
      # |> Bonfire.Repo.all()
  end

  def maybe_my_like(q, %{id: current_user_id} = _current_user) do
    q
    |> join(:left, [a], l in Like, on: l.liked_id == a.object_id and l.liker_id == ^current_user_id)
    |> preload([l], activity: [:my_like])
  end
  def maybe_my_like(q, _), do: q

  def maybe_my_boost(q, %{id: current_user_id} = _current_user) do
    q
    |> join(:left, [a], l in Boost, on: l.boosted_id == a.object_id and l.booster_id == ^current_user_id)
    |> preload([l], activity: [:my_boost])
  end
  def maybe_my_boost(q, _), do: q

  def maybe_my_flag(q, %{id: current_user_id} = _current_user) do
    q
    |> join(:left, [a], l in Flag, on: l.flagged_id == a.object_id and l.flagger_id == ^current_user_id)
    |> preload([l], activity: [:my_flag])
  end
  def maybe_my_flag(q, _), do: q

end
