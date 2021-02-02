defmodule Bonfire.Me.Social.Circles do

  alias CommonsPub.Circles.Circle
  import Bonfire.Me.Integration

  def circles do
    %{ guest:        "RAND0MSTRANGERS0FF1NTERNET",
       local:        "VSERSFR0MY0VR10CA11NSTANCE",
       activity_pub: "FEDERATEDW1THANACT1V1TYPVB" }
  end

  def circle_names do
    %{ guest:        "Guests",
       local:        "Local Users",
       activity_pub: "Remote Users (ActivityPub)" }
  end

  def circles_fixture do
    Enum.map(circles(), fn {k, v} -> %{id: v} end)
  end

  def circles_named_fixture do
    Enum.map(circles(), fn {k, v} -> %{id: v, name: circle_names()[k]} end)
  end

  def create(%{}=attrs) do
    repo().insert(changeset(:create, attrs))
  end

  def changeset(:create, attrs), do: Circle.changeset(attrs)

end
