defmodule Bonfire.Me.Identity.Users.Circles do

  alias Bonfire.Data.Identity.User
  alias Bonfire.Data.Social.Circle
  alias Pointers.Changesets
  import Bonfire.Me.Integration

  ## invariants:

  ## * Created circles will have the user as a caretaker

  @doc "A changeset func for creating a circle owned by the provided user."
  def create_changeset(%User{}=user, attrs) do
    Circle.changeset(attrs)
    |> Changesets.cast_assoc(:named, attrs)
    |> Changesets.cast_assoc(:caretaker, %{caretaker_id: user.id})
  end

  import Ecto.Query
  import Bonfire.Me.Queries

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
