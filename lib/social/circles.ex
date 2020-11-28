defmodule Bonfire.Me.Circles do

  alias CommonsPub.Circles.{Circle, Encircle}

  def guests_id, do: "RAND0MSTRANGERS0FF1NTERNET"
  def local_users_id, do: "VSERSFR0MY0VR10CA11NSTANCE"

  defp repo, do: Application.get_env(:bonfire_me, :repo_module)

  def create(type, attrs) when is_map(attrs) and not is_map_key(attrs, :__struct__) do
    repo().single(changeset(:create, type, attrs))
  end

  def changeset(:create, Circle, attrs), do: Circle.changeset(attrs)
  def changeset(:create, Encircle, attrs), do: Encircle.changeset(attrs)

end
