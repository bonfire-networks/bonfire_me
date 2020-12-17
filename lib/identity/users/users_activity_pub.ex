defmodule Bonfire.Me.Users.ActivityPub do

  # alias Bonfire.Me.Users
  # alias CommonsPub.Peers.Peer
  # alias CommonsPub.Users.User
  # import Ecto.Query
  # import Pointers.Queries

  # import Bonfire.Common.Config, only: [repo: 0]

  # def by_username(username) when is_binary(username),
  #   do: repo().single(by_username_query(username))

  # def by_username_query(username) do
  #   # from(u in User, as: :user)
  #   # |> mix_in(user: [:profile, :character, :actor])
  #   # |> left_mix_in(user: [:accounted, :peer])
  #   # |> join(:left, x in assoc(as(:peered), :peer), as: :peer)
  #   # |> where(as(:character).username == ^username)
  #   # |> preload([
  #   #   profile: as(:profile), character: as(:character),
  #   #   actor: as(:actor), accounted: as(:accounted),
  #   #   peered: {as(:peered), peer: as(:peer)}
  #   # ])
  #   # |> inload([
  #   #   accounted: :account,
  #   #   peered: :peer,
  #   #   profile: [], character: [], actor: []
  #   # ])
  # end

  # @doc "Creates a remote user"
  # def create(params, %Peer{id: id}) do
  #   changeset(params)
  #   |> Changesets.change(peer_id: id)
  #   |> repo().insert()
  # end

  # def changeset(user \\ %User{}, params) do
  #   User.changeset(user, params)
  #   |> Changesets.cast_assoc(:accounted, params)
  #   |> Changesets.cast_assoc(:character, params)
  #   |> Changesets.cast_assoc(:profile, params)
  #   |> Changesets.cast_assoc(:actor, params)
  # end

  # @doc "Updates a remote user"
  # def update(user, params) do
  #   repo().update(changeset(user, params))
  # end

end
