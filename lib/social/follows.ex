defmodule Bonfire.Me.Social.Follows do

  alias Bonfire.Data.Identity.User
  alias Bonfire.Data.Social.Follow
  import Ecto.Query
  import Bonfire.Me.Integration

  def following?(%User{}=user, followed), do: not is_nil(get!(user, followed))
  def get(%User{}=user, followed), do: repo().single(by_both_q(user, followed))
  def get!(%User{}=user, followed), do: repo().one(by_both_q(user, followed))
  def by_follower(%User{}=user), do: repo().all(by_follower_q(user))
  def by_followed(%User{}=user), do: repo().all(by_followed_q(user))
  def by_any(%User{}=user), do: repo().all(by_any_q(user))

  def follow(%User{} = follower, %{} = followed) do
    with {:ok, follow} <- create(follower, followed) do
      Bonfire.Me.Social.Activities.create(follower, :follow, followed)
      {:ok, follow}
    end
  end

  def unfollow(%User{}=follower, %{}=followed) do
    delete_by_both(follower, followed)
  end

  defp create(%{} = follower, %{} = followed) do
    changeset(follower, followed) |> repo().insert()
  end

  defp changeset(%{id: follower}, %{id: followed}) do
    Follow.changeset(%Follow{}, %{follower_id: follower, followed_id: followed})
  end

  @doc "Delete Follows where i am the follower"
  defp delete_by_follower(%User{}=me), do: elem(repo().delete_all(by_follower_q(me)), 1)

  @doc "Delete Follows where i am the followed"
  defp delete_by_followed(%User{}=me), do: elem(repo().delete_all(by_followed_q(me)), 1)

  @doc "Delete Follows where i am the follower or the followed."
  defp delete_by_any(%User{}=me), do: elem(repo().delete_all(by_any_q(me)), 1)

  @doc "Delete Follows where i am the follower and someone else is the followed."
  defp delete_by_both(%User{}=me, %{}=followed), do: elem(repo().delete_all(by_both_q(me, followed)), 1)

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

  def by_both_q(%User{id: follower}, %{id: followed}), do: by_both_q(follower, followed)

  def by_both_q(follower, followed) when is_binary(follower) and is_binary(followed) do
    from f in Follow,
      where: f.follower_id == ^follower or f.followed_id == ^followed,
      select: f.id
  end

end
