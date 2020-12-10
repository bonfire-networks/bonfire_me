defmodule Bonfire.Me.Fixtures do

  alias Bonfire.Data.AccessControl.{Access, Acl, Controlled, Grant, Interact, Verb}
  alias Bonfire.Data.Identity.User
  alias Bonfire.Me.AccessControl.{Accesses, Verbs}
  alias Bonfire.Me.Identity.Users
  alias Ecto.UUID
  alias Pointers.ULID
  import Bonfire.Me.Integration

  def insert() do
    # to start with, we need our special users
    guest = Users.guest_user_id()
    local = Users.local_user_id()
    {2, _} = repo().insert_all(User, [%{id: guest}, %{id: local}])
    # now we need to insert verbs for our standard actions
    verbs  = Verbs.verbs()
    read   = Keyword.fetch!(verbs, :read)
    see    = Keyword.fetch!(verbs, :see)
    edit   = Keyword.fetch!(verbs, :edit)
    delete = Keyword.fetch!(verbs, :delete)
    {4, _} = repo().insert_all Verb,
      [ %{id: read,   verb: "read"},
        %{id: see,    verb: "see"},
        %{id: edit,   verb: "edit"},
        %{id: delete, verb: "delete"},
      ]
    # then our standard accesses
    accesses   = Accesses.accesses()
    read_only  = Keyword.fetch!(accesses, :read_only)
    administer = Keyword.fetch!(accesses, :administer)
    {2, _} = repo().insert_all(Access, [%{id: read_only}, %{id: administer}])
    # now we have to hook up the verbs to the accesses
    {6, _} = repo().insert_all Interact, [
      %{id: ULID.generate(), access_id: read_only,  verb_id: read},
      %{id: ULID.generate(), access_id: read_only,  verb_id: see},
      %{id: ULID.generate(), access_id: administer, verb_id: read},
      %{id: ULID.generate(), access_id: administer, verb_id: see},
      %{id: ULID.generate(), access_id: administer, verb_id: edit},
      %{id: ULID.generate(), access_id: administer, verb_id: delete},
    ]
    # read_only and read are visible to local users, so they need an
    # acl and a controlled mixin that associates them
    read_only_acl = Pointers.ULID.generate()
    {1, _} = repo().insert_all(Acl,[%{id: read_only_acl}])
    {2, _} = repo().insert_all Controlled, [
      %{id: read,      acl_id: read_only_acl},
      %{id: read_only, acl_id: read_only_acl},
    ]
    # finally, we do a horrible thing and grant read_only to
    # read_only_acl and it actually kinda works out because of the
    # indirection through pointer.
    read_only_grant = Pointers.ULID.generate()
    {1, _} = repo().insert_all Grant, [
      %{ id: read_only_grant,  acl_id: read_only_acl,
         access_id: read_only, subject_id: local },
    ]
  end

end
