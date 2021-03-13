defmodule Bonfire.Me.Users.Circles do

  alias Bonfire.Data.Identity.User
  alias Bonfire.Data.Social.Named
  alias Bonfire.Data.Social.Circle
  alias Bonfire.Data.Social.Encircle
  alias Bonfire.Data.Identity.Caretaker

  alias Bonfire.Boundaries.Circles

  alias Ecto.Changeset
  import Bonfire.Me.Integration
  alias Bonfire.Common.Utils

  ## invariants:
  ## * Created circles will have the user as a caretaker


  @doc "Create a circle owned by the provided user and with the user in the circle."
  def create(%User{}=user, name \\ nil, %{}=attrs \\ %{}) do
    repo().insert(changeset(:create,
    user,
    attrs
      |> Utils.deep_merge(%{
        named: %{name: name},
        encircles: [%{subject_id: user.id}] # add user to circle
      })
    ))
  end

  def changeset(:create, %User{}=user, attrs) do
    Circle.changeset(attrs)
    |> Changeset.cast(%{
      caretaker: %{caretaker_id: user.id}
    }, [])
    |> Changeset.cast_assoc(:named, with: &Named.changeset/2)
    |> Changeset.cast_assoc(:caretaker, with: &Caretaker.changeset/2)
    |> Changeset.cast_assoc(:encircles, with: &Encircle.changeset/2)
    |> IO.inspect
  end

  import Ecto.Query
  import Bonfire.Boundaries.Queries

  @doc """
  Lists the circles we are the registered caretakers of that we are
  permitted to see. If any circles are created without permitting the
  user to see them, they will not be shown.
  """
  def list_my(%User{}=user) do
    repo().all(list_my_q(user))
  end

  @doc "query for `list_my`"
  def list_my_q(%User{id: user_id}=user) do
    cs = can_see?(:circle, user)
    from circle in Circle, as: :circle,
      join: caretaker in assoc(circle, :caretaker),
      join: named in assoc(circle, :named),
      left_lateral_join: _cs in ^cs,
      where: caretaker.caretaker_id == ^user_id,
      preload: [caretaker: caretaker]
  end

end
