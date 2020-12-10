defmodule Bonfire.Me.Users.Follows do

  alias Bonfire.Data.Identity.User
  alias Bonfire.Data.Social.Follow
  import Ecto.Query
  import Bonfire.Me.Integration

  def by_follower(%User{}=user), do: Repo.all(by_follower_q(user))
  def by_followed(%User{}=user), do: Repo.all(by_followed_q(user))
  def by_any(%User{}=user), do: Repo.all(by_any_q(user))

  def follow(%User{}=_follower, %_thing{}=_followed) do
  end

  def unfollow(%User{}=_follower, %_thing{}=_followed) do
  end

  def delete(%User{}=_follower, %Follow{}=_follow) do
  end

  @doc "Follows where i am the follower"
  def delete_by_follower(%User{}=me), do: elem(repo().delete_all(by_follower_q(me)), 1)

  @doc "Follows where i am the followed"
  def delete_by_followed(%User{}=me), do: elem(repo().delete_all(by_followed_q(me)), 1)

  @doc "Follows where i am the follower or the followed."
  def delete_by_any(%User{}=me), do: elem(repo().delete_all(by_any_q(me)), 1)

  def by_follower_q(%User{id: id}) do
    from f in Follow,
      where: f.follower_id == ^id,
      select: f.id
  end

  def by_followed_q(%User{id: id}) do
    from f in Follow,
      where: f.followed_id == ^id,
      select: f.id
  end

  def by_any_q(%User{id: id}) do
    from f in Follow,
      where: f.follower_id == ^id or f.followed_id == ^id,
      select: f.id
  end

end
