defmodule Bonfire.Me.AccessControl.Verbs do

  alias Bonfire.Data.AccessControl.Verb
  import Bonfire.Me.Integration

  def verbs, do: [
    read: "READ1NGSVTTER1YFVNDAMENTA1",
    see: "0BSERV1NG11ST1NGSEX1STENCE",
    edit: "CHANG1NGVA1VES0FPR0PERT1ES",
    delete: "MAKESTVFFG0AWAYPERMANENT1Y"
  ]

  def create(%{}=attrs) when not is_struct(attrs) do
    repo().insert(changeset(attrs))
  end

  def changeset(verb \\ %Verb{}, attrs) do
    Verb.changeset(verb, attrs)
  end

end
