defmodule Bonfire.Me.Social.Circles do

  alias CommonsPub.Circles.Circle
  import Bonfire.Me.Integration

  def circles do
    %{ guest:        "RAND0MSTRANGERS0FF1NTERNET",
       local:        "VSERSFR0MY0VR10CA11NSTANCE",
       activity_pub: "FEDERATEDW1THANACT1V1TYPVB" }
  end

  def create(%{}=attrs) do
    repo().insert(changeset(:create, attrs))
  end

  def changeset(:create, attrs), do: Circle.changeset(attrs)

end
