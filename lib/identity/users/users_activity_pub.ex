defmodule Bonfire.Me.Users.ActivityPub do
  alias Bonfire.Me.Identity.Users
  alias Bonfire.Data.ActivityPub.Peer
  alias Bonfire.Data.Identity.User
  alias Bonfire.Me.Identity.Users.Queries

  import Bonfire.Me.Integration
  import Pointers.Changesets

  def by_username(username) when is_binary(username),
    do: repo().single(Queries.by_username(username))

  @doc "Creates a remote user"
  def create(params, %Peer{id: id}) do
    Users.changeset(:create, %User{}, params, :remote)
    |> Changesets.change(peer_id: id)
    |> repo().insert()
  end

  @doc "Updates a remote user"
  def update(user, params) do
    repo().update(Users.changeset(:update, user, params))
  end
end
