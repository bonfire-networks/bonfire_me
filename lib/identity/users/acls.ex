defmodule Bonfire.Me.Identity.Users.Acls do

  alias Bonfire.Data.AccessControl.{Access, Acl}
  alias Bonfire.Data.Identity.User
  import Bonfire.Me.Integration
  import Bonfire.Me.Queries
  import Ecto.Query

  ## invariants:

  ## * All a user's ACLs will have the user as an administrator but it
  ##   will be hidden from the user

  # def create(%User{}=user) do
  # end

  @doc """
  Lists the ACLs permitted to see.
  """
  def list_my(%User{}=user) do
    repo().all(list_my_q(user))
  end

  @doc "query for `list_my`"
  def list_my_q(%User{id: user_id}=user) do
    cs = can_see?(:acl, user)
    from acl in Acl, as: :acl,
      # join: caretaker in assoc(acl, :caretaker),
      join: named in assoc(acl, :named),
      left_lateral_join: _cs in ^cs,
      # where: caretaker.caretaker_id == ^user_id,
      preload: [named: named]
  end

end
