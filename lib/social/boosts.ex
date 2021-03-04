defmodule Bonfire.Me.Social.Boosts do

  alias Bonfire.Data.Identity.User
  alias Bonfire.Data.Social.Boost
  alias Bonfire.Data.Social.BoostCount
  alias Bonfire.Me.Social.{Activities, FeedActivities}
  import Ecto.Query
  import Bonfire.Me.Integration
  alias Bonfire.Common.Utils

  def boosted?(%User{}=user, boosted), do: not is_nil(get!(user, boosted))
  def get(%User{}=user, boosted), do: repo().single(by_both_q(user, boosted))
  def get!(%User{}=user, boosted), do: repo().one(by_both_q(user, boosted))
  def by_booster(%User{}=user), do: repo().all(by_booster_q(user))
  def by_boosted(%User{}=user), do: repo().all(by_boosted_q(user))
  def by_any(%User{}=user), do: repo().all(by_any_q(user))

  def boost(%User{} = booster, %{} = boosted) do
    with {:ok, boost} <- create(booster, boosted) do
      # TODO: increment the boost count
      FeedActivities.publish(booster, :boost, boosted)
      {:ok, boost}
    end
  end

  def unboost(%User{}=booster, %{}=boosted) do
    delete_by_both(booster, boosted) # delete the Boost
    Activities.delete_by_subject_verb_object(booster, :boost, boosted) # delete the boost activity & feed entries
    # TODO: decrement the boost count
  end

  defp create(%{} = booster, %{} = boosted) do
    changeset(booster, boosted) |> repo().insert()
  end

  defp changeset(%{id: booster}, %{id: boosted}) do
    Boost.changeset(%Boost{}, %{booster_id: booster, boosted_id: boosted})
  end

  @doc "Delete boosts where i am the booster"
  defp delete_by_booster(%User{}=me), do: elem(repo().delete_all(by_booster_q(me)), 1)

  @doc "Delete boosts where i am the boosted"
  defp delete_by_boosted(%User{}=me), do: elem(repo().delete_all(by_boosted_q(me)), 1)

  @doc "Delete boosts where i am the booster or the boosted."
  defp delete_by_any(%User{}=me), do: elem(repo().delete_all(by_any_q(me)), 1)

  @doc "Delete boosts where i am the booster and someone else is the boosted."
  defp delete_by_both(%User{}=me, %{}=boosted), do: elem(repo().delete_all(by_both_q(me, boosted)), 1)

  def by_booster_q(%User{id: id}) do
    from f in Boost,
      where: f.booster_id == ^id,
      select: f.id
  end

  def by_boosted_q(%User{id: id}) do
    from f in Boost,
      where: f.boosted_id == ^id,
      select: f.id
  end

  def by_any_q(%User{id: id}) do
    from f in Boost,
      where: f.booster_id == ^id or f.boosted_id == ^id,
      select: f.id
  end

  def by_both_q(%User{id: booster}, %{id: boosted}), do: by_both_q(booster, boosted)

  def by_both_q(booster, boosted) when is_binary(booster) and is_binary(boosted) do
    from f in Boost,
      where: f.booster_id == ^booster or f.boosted_id == ^boosted,
      select: f.id
  end

end
