defmodule Bonfire.Me.Identity.Users.Accesses do

  alias Bonfire.Data.AccessControl.{Access, Acl}
  alias Bonfire.Data.Identity.User
  import Bonfire.Me.Integration
  import Bonfire.Me.Queries

  ## invariants:

  ## * All a user's Accesses will have the user as an administrator but it
  ##   will be hidden from the user

  def create(%User{}=_user) do
  end

  @doc """
  Lists all accesses we are permitted to see. Not just by this user.
  """
  def list_visible(%User{}=user) do
    repo().all(list_visible_q(user))
  end

  import Ecto.Query

  @doc "query for `list_visible`"
  def list_visible_q(%User{id: user_id}=user) do
    cs = can_see?(:access, user)
    from access in Access, as: :access,
      # join: caretaker in assoc(access, :caretaker),
      join: named in assoc(access, :named),
      left_lateral_join: _cs in ^cs,
      # where: caretaker.caretaker_id == ^user_id,
      preload: [named: named]
  end

end
