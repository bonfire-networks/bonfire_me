defmodule Bonfire.Me.Users.Accesses do

  alias Bonfire.Data.AccessControl.Access
  alias Bonfire.Boundaries.Accesses
  alias Bonfire.Data.Identity.User

  import Bonfire.Me.Integration
  import Bonfire.Boundaries.Queries
  alias Bonfire.Common.Utils

  ## invariants:

  ## * All a user's Accesses will have the user as an administrator but it
  ##   will be hidden from the user

  @doc "Create an Access for the provided user"
  def create(%User{}=user, name \\ nil, %{}=attrs \\ %{}) do
    repo().insert(changeset(:create,
    user,
    attrs
      |> Utils.deep_merge(%{
        named: %{name: name},
        caretaker: %{caretaker_id: user.id}
      })
    ))
  end

  def changeset(:create, %User{}=_user, attrs) do
    Accesses.changeset(attrs)
  end

  @doc """
  Lists all accesses we are permitted to see. Not just by this user.
  """
  def list_visible(%User{}=user) do
    repo().all(list_visible_q(user))
  end

  import Ecto.Query

  @doc "query for `list_visible`"
  def list_visible_q(%User{id: _user_id}=user) do
    cs = can_see?(:access, user)
    from access in Access, as: :access,
      join: named in assoc(access, :named),
      left_lateral_join: cs in ^cs,
      where: cs.can_see == true,
      preload: [named: named]
  end

  @doc """
  Lists the accesses we are the registered caretakers of that we are
  permitted to see. If any are created without permitting the
  user to see them, they will not be shown.
  """
  def list_my(%User{}=user) do
    repo().all(list_my_q(user))
  end

  @doc "query for `list_my`"
  def list_my_q(%User{id: user_id}=user) do
    list_visible_q(user)
    |> join(:inner, [access: access], caretaker in assoc(access, :caretaker), as: :caretaker)
    |> where([caretaker: caretaker], caretaker.caretaker_id == ^user_id)
  end
end
