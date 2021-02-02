defmodule Bonfire.Me.Fixtures do

  alias Bonfire.Data.AccessControl.{Access, Acl, Controlled, Grant, Interact, Verb}
  alias Bonfire.Data.Identity.User
  alias Bonfire.Data.Social.{Circle, Named}
  alias Bonfire.Me.AccessControl.{Accesses, Verbs, Acls, Grants}
  alias Bonfire.Me.Identity.Users
  alias Bonfire.Me.Social.Circles
  alias Ecto.UUID
  alias Pointers.ULID
  import Bonfire.Me.Integration

  def insert() do

    # to start with, we need our special users
    circles = Circles.circles()

    repo().insert_all(
      Circle,
      Circles.circles_fixture(),
      on_conflict: :nothing
    )

    repo().insert_all(
      Named,
      Circles.circles_named_fixture(),
      on_conflict: :nothing
    )

    # now we need to insert verbs for our standard actions
    verbs  = Verbs.verbs()

    repo().insert_all(
      Verb,
      Verbs.verbs_fixture(),
      on_conflict: :nothing
    )

    # then our standard accesses
    accesses = Accesses.accesses()

    repo().insert_all(
      Access,
      Accesses.accesses_fixture(),
      on_conflict: :nothing
    )

    # now we have to hook up the permission-related verbs to the accesses
    repo().insert_all(
      Interact,
      [
        %{id: ULID.generate(), access_id: accesses.read_only,  verb_id: verbs.read},
        %{id: ULID.generate(), access_id: accesses.read_only,  verb_id: verbs.see},
        %{id: ULID.generate(), access_id: accesses.administer, verb_id: verbs.read},
        %{id: ULID.generate(), access_id: accesses.administer, verb_id: verbs.see},
        %{id: ULID.generate(), access_id: accesses.administer, verb_id: verbs.edit},
        %{id: ULID.generate(), access_id: accesses.administer, verb_id: verbs.delete},
      ],
      on_conflict: :nothing
    )

    # some of these things are public
    # read_only and read are visible to local users, so they need an
    # acl and a controlled mixin that associates them
    acls = Acls.acls()

    repo().insert_all(
      Acl,
      [ %{id: acls.read_only} ],
      on_conflict: :nothing
    )

    repo().insert_all(
      Controlled,
      [
        %{id: verbs.read,     acl_id: acls.read_only},
        %{id: acls.read_only, acl_id: acls.read_only},
      ],
      on_conflict: :nothing
    )

    # finally, we do a horrible thing and grant read_only to
    # read_only_acl and it actually kinda works out because of the
    # indirection through pointer
    grants = Grants.grants()

    repo().insert_all(
      Grant,
      [
        %{
         id:         grants.read_only,
         acl_id:     acls.read_only,
         access_id:  accesses.read_only,
         subject_id: circles.local
        },
      ],
      on_conflict: :nothing
    )
  end

end
