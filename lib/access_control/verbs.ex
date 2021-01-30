defmodule Bonfire.Me.AccessControl.Verbs do

  alias Bonfire.Data.AccessControl.Verb
  import Bonfire.Me.Integration

  def verbs do
    %{
       read:    "READ1NGSVTTER1YFVNDAMENTA1",
       see:     "0BSERV1NG11ST1NGSEX1STENCE",
       create:  "CREATE0RP0STBRANDNEW0BJECT",
       edit:    "CHANG1NGVA1VES0FPR0PERT1ES",
       delete:  "MAKESTVFFG0AWAYPERMANENT1Y",
       follow:  "T0SVBSCR1BET0THE0VTPVT0F1T",
       like:    "11KES1ND1CATEAM11DAPPR0VA1",
       boost:    "B00ST0R0RANN0VCEANACT1V1TY",
       mention: "REFERENC1NGTH1NGSE1SEWHERE",
       tag:     "CATEG0R1S1NGNGR0VP1NGSTVFF",
    }
  end

  def verbs_fixture do
    Enum.map(verbs(), fn {k, v} -> %{id: v, verb: to_string(k)} end)
  end

  def create(%{}=attrs) when not is_struct(attrs) do
    repo().insert(changeset(attrs))
  end

  def changeset(verb \\ %Verb{}, attrs) do
    Verb.changeset(verb, attrs)
  end

end
