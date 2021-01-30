defmodule Bonfire.Me.Fixtures do

  alias Bonfire.Data.AccessControl.{Access, Acl, Controlled, Grant, Interact, Verb}
  alias Bonfire.Data.Identity.User
  alias Bonfire.Data.Social.{Circle, Named}
  alias Bonfire.Me.AccessControl.{Accesses, Verbs}
  alias Bonfire.Me.Identity.Users
  alias Bonfire.Me.Social.Circles
  alias Ecto.UUID
  alias Pointers.ULID
  import Bonfire.Me.Integration

  def insert() do

    # to start with, we need our special users
    circles = Circles.circles()
    repo().insert_all Circle, [
      %{id: circles.guest},
      %{id: circles.local},
      %{id: circles.activity_pub},
    ]
    repo().insert_all Named, [
      %{id: circles.guest,        name: "Guests"},
      %{id: circles.local,        name: "Local Users"},
      %{id: circles.activity_pub, name: "Remote Users (ActivityPub)"},
    ]

    # now we need to insert verbs for our standard actions
    verbs  = Verbs.verbs()
    repo().insert_all(
      Verb,
      Verbs.verbs_fixture(),
      on_conflict: :nothing
    )

    # then our standard accesses
    accesses = Accesses.accesses()
    repo().insert_all Access, [
      %{id: accesses.read_only},
      %{id: accesses.administer},
    ]

    # now we have to hook up the permission-related verbs to the accesses
    repo().insert_all Interact, [
      %{id: ULID.generate(), access_id: accesses.read_only,  verb_id: verbs.read},
      %{id: ULID.generate(), access_id: accesses.read_only,  verb_id: verbs.see},
      %{id: ULID.generate(), access_id: accesses.administer, verb_id: verbs.read},
      %{id: ULID.generate(), access_id: accesses.administer, verb_id: verbs.see},
      %{id: ULID.generate(), access_id: accesses.administer, verb_id: verbs.edit},
      %{id: ULID.generate(), access_id: accesses.administer, verb_id: verbs.delete},
    ]

    # some of these things are public
    # read_only and read are visible to local users, so they need an
    # acl and a controlled mixin that associates them
    acls = %{read_only: Pointers.ULID.generate()}
    {1, _} = repo().insert_all(Acl,[ %{id: acls.read_only} ])
    {2, _} = repo().insert_all Controlled, [
      %{id: verbs.read,     acl_id: acls.read_only},
      %{id: acls.read_only, acl_id: acls.read_only},
    ]

    # finally, we do a horrible thing and grant read_only to
    # read_only_acl and it actually kinda works out because of the
    # indirection through pointer.
    grants = %{read_only: Pointers.ULID.generate()}
    {1, _} = repo().insert_all Grant, [
      %{ id:         grants.read_only,
         acl_id:     acls.read_only,
         access_id:  accesses.read_only,
         subject_id: circles.local },
    ]
  end

end
