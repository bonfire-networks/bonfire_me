# defmodule Bonfire.Me.Users.Register do

#   # alias Bonfire.Data.Identity.Account
#   alias Bonfire.Data.Identity.User
#   alias Bonfire.Boundaries.Accesses
#   alias Bonfire.Me.Users.CreateUserFields
#   alias Pointers.Changesets

#   def form(attrs \\ %{}, _opts \\ []) do
#     CreateUserFields.changeset(attrs)
#     |> Map.put(:action, :insert)
#   end

#   def model(user \\ %User{}, attrs) do
#     User.changeset(user, attrs)
#     |> Changesets.cast_assoc(:accounted, attrs)
#     |> Changesets.cast_assoc(:character, attrs)
#     |> Changesets.cast_assoc(:profile, attrs)
#     |> Changesets.cast_assoc(:actor, attrs)
#   end

#   # We create a user.
#   #   A user needs some default ACLs creating:
#   #     * Public
#   #     * Instance Local
#   #     * Followers
#   #   They all need to reference the predefined verbs
#   def acls() do
#     %{name: "Public"}
#     %{name: "Local"}
#     %{name: "Followers"}
#     %{name: "Read only"}
#   end

#   def public_acl(%User{}=_user) do
#     %{name: "Public"}
#   end

#   def local_acl(%User{}=_user) do
#   end

#   def interact_access(%User{id: user_id}=_user) do
#     Access.changeset(:create, Bonfire.Data.AccessControl.Access, %{name: "Interact", can_see: true, can_read: true})
#     |> Changesets.put_assoc(:object, %{custodian_id: user_id})
#   end

#   def self_acl(%User{}=_user) do
#     # FIXME?
#   end

#   defp self_access(%User{}=_user) do
#     Accesses.create(%{name: "", can_see: true, can_read: true})
#   end

#  # owned by commons
#   # access: full, read only, interact
#     # acl:
#       # owned by: self
#       # no acl
#       # access: read only

#  # owned by user:
#   # acl:
#     # (self)
#        # owned by self
#        # no acl
#     # public read
#        # owned by self
#        # acl: (self)
#     # public interactions
#     # public read, local user interactions
#     # local user read
#  #
#  # create commons user
#  # create access read-only
#  # create acl local-read-only
#  # create object for access read-only, acl local-read-only, caretaker commons
#  #
#  #
#  #
#  #
#  #
#  #
#  #
#  #
#  #
#  #
#  #
# end
