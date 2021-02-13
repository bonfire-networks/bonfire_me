defmodule Bonfire.Me.Social.Activities do

  alias Bonfire.Data.Social.{Activity}
  alias Bonfire.Data.Identity.{User}
  alias Bonfire.Me.AccessControl.Verbs
  alias Ecto.Changeset
  import Ecto.Query
  import Bonfire.Me.Integration

  @doc """
  Create an Activity
  NOTE: you will usually want to use `Feeds.publish/3` instead
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

  def by_user(%{id: user_id}), do: by_user(user_id)
  def by_user(user_id) do
    repo().all(by_user_query(user_id))
  end

  def by_subject(%User{id: user_id}), do: by_user(user_id)
  def by_subject(%{id: subject_id}), do: by_subject(subject_id)
  def by_subject(subject_id) do
    repo().all(by_subject_query(subject_id))
  end

  @doc "Delete an activity (usage by things like unlike)"
  def delete_by_subject_verb_object(%{}=subject, verb, %{}=object) do
    q = by_subject_verb_object_q(subject, Verbs.verbs()[verb], object)
    Bonfire.Me.Social.FeedActivities.delete_for_object(repo.one(q)) # TODO: see why cascading delete doesn't take care of this
    elem(repo().delete_all(q), 1)
  end

  def by_subject_verb_object_q(%{id: subject}, verb, %{id: object}), do: by_subject_verb_object_q(subject, verb, object)

  def by_subject_verb_object_q(subject, verb, object) when is_binary(subject) and is_binary(object) do
    from f in Activity,
      where: f.subject_id == ^subject and f.object_id == ^object and f.verb_id == ^verb,
      select: f.id
  end

  def by_user_query(subject_id) do
    from a in Activity,
     left_join: u in assoc(a, :subject_user),
     left_join: up in assoc(u, :profile),
     left_join: uc in assoc(u, :character),
     join: o in assoc(a, :object),
     join: v in assoc(a, :verb),
     where: a.subject_id == ^subject_id,
     preload: [subject_user: {u, profile: up, character: uc}, object: o, verb: v]
  end

  def by_subject_query(subject_id) do
    from a in Activity,
     join: u in assoc(a, :subject),
     join: o in assoc(a, :object),
     join: v in assoc(a, :verb),
     where: a.subject_id == ^subject_id,
     preload: [subject: u, object: o, verb: v]
  end
end
