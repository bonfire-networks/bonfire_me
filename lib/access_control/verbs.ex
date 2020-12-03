defmodule Bonfire.Me.AccessControl.Verbs do

  alias Bonfire.Data.AccessControl.Verb

  # from our fixtures
  def read_id, do: "READ1NGSVTTER1YFVNDAMENTA1"
  def see_id, do: "0BSERV1NG11ST1NGSEX1STENCE"

  defp repo, do: Application.get_env(:bonfire_me, :repo_module)

  def create(%{}=attrs) when not is_struct(attrs) do
    repo().insert(changeset(attrs))
  end

  def changeset(verb \\ %Verb{}, attrs) do
    Verb.changeset(verb, attrs)
  end

end
