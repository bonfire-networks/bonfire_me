defmodule Bonfire.Me.Social.Activities do

  alias Bonfire.Data.Social.{Activity}
  alias Bonfire.Me.AccessControl.Verbs
  alias Ecto.Changeset
  import Ecto.Query

  import Bonfire.Me.Integration


  def create(%{id: subject_id}=_subject, verb, %{id: object_id}=_object) when is_atom(verb) do
    verb_id = Verbs.verbs()[verb]
    attrs = %{subject_id: subject_id, verb_id: verb_id, object_id: object_id}
    repo().put(changeset(attrs))
  end

  def changeset(activity \\ %Activity{}, %{} = attrs) do
    Activity.changeset(activity, attrs)
  end

  def by_subject(%{id: subject_id}), do: by_subject(subject_id)
  def by_subject(subject_id) do
    repo().all(by_subject_query(subject_id))
  end

  def by_subject_query(subject_id) do
    from a in Activity,
     join: s in assoc(a, :subject),
     join: o in assoc(a, :object),
     join: v in assoc(a, :verb),
     where: a.subject_id == ^subject_id,
     preload: [subject: s, object: o, verb: v]
  end
end
