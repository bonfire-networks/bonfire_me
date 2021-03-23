defmodule Bonfire.Me.Users.Acls do

  alias Bonfire.Data.AccessControl.{Access, Acl}
  alias Bonfire.Boundaries.Acls
  alias Bonfire.Data.Identity.User

  import Bonfire.Me.Integration
  import Bonfire.Boundaries.Queries
  import Ecto.Query
  alias Ecto.Changeset
  alias Bonfire.Common.Utils

  ## invariants:

  ## * All a user's ACLs will have the user as an administrator but it
  ##   will be hidden from the user

  @doc "Create a Acls for the provided user"
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

  def changeset(:create, %User{}=user, attrs) do
    Acls.changeset(attrs)
  end

  @doc """
  Lists the ACLs permitted to see.
  """
  def list_visible(%User{}=user) do
    repo().all(list_my_q(user))
  end

  @doc "query for `list_visible`"
  def list_visible_q(%User{id: user_id}=user) do
    cs = can_see?(:acl, user)
    from acl in Acl, as: :acl,
      join: named in assoc(acl, :named),
      left_lateral_join: cs in ^cs,
      where: cs.can_see == true,
      preload: [named: named]
  end

  @doc """
  Lists the ACLs we are the registered caretakers of that we are
  permitted to see. If any are created without permitting the
  user to see them, they will not be shown.
  """
  def list_my(%User{}=user) do
    repo().all(list_my_q(user))
  end

  @doc "query for `list_my`"
  def list_my_q(%User{id: user_id}=user) do
    list_visible_q(user)
    |> join(:inner, [acl: acl], caretaker in assoc(acl, :caretaker), as: :caretaker)
    |> where([caretaker: caretaker], caretaker.caretaker_id == ^user_id)
  end

end
