defmodule Bonfire.Me.Fixtures do

  alias Bonfire.Repo
  alias Bonfire.Data.AccessControl.{Access, Acl, Controlled, Grant, Interact, Verb}
  alias Bonfire.Data.Identity.User
  alias Bonfire.Me.AccessControl.{Accesses, Verbs}
  alias Bonfire.Me.Identity.Users

  def insert() do
    # to start with, we need our special users
    guest = Users.guest_user_id()
    local = Users.local_user_id()
    {2, _} = Repo.insert_all(User, [%{id: guest}, %{id: local}])

    # now we need to insert verbs for our standard actions
    read = Verbs.read_id()
    see = Verbs.see_id()
    {2, _} = Repo.insert_all(Verb, [%{id: read, verb: "read"}, %{id: see, verb: "see"}])
    # then our standard accesses 
    read_only = Accesses.read_only_id()
    administer = Accesses.administer_id()
    {2, _} = Repo.insert_all(Access, [%{id: read_only}, %{id: administer}])
    # read_only and read are visible to local users, so they need an
    # acl and a controlled mixin that associates them
    read_acl = Pointers.ULID.generate()
    read_only_acl = Pointers.ULID.generate()
    {2, _} = Repo.insert_all(Acl,[%{id: read_acl}, %{id: read_only_acl}])
    {2, _} = Repo.insert_all Controlled, [
      %{id: read, acl_id: read_acl},
      %{id: read_only, acl_id: read_only_acl},
    ]
    # finally, we do a horrible thing and grant read_only to read_acl
    # and read_only_acl and it actually kinda works out because of the
    # indirection through pointer.
    read_grant = Pointers.ULID.generate()
    read_only_grant = Pointers.ULID.generate()
    {2, _} = Repo.insert_all Grant, [
      %{ id: read_grant, subject_id: local, acl_id: read_acl, access_id: read_only },
      %{ id: read_only_grant, subject_id: local, acl_id: read_only_acl, access_id: read_only },
    ]
  end

end
