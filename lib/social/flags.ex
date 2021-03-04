defmodule Bonfire.Me.Social.Flags do

  alias Bonfire.Data.Identity.User
  alias Bonfire.Data.Social.Flag
  alias Bonfire.Data.Social.FlagCount
  alias Bonfire.Me.Social.{Activities, FeedActivities}
  import Ecto.Query
  import Bonfire.Me.Integration
  alias Bonfire.Common.Utils

  def flagged?(%User{}=user, flagged), do: not is_nil(get!(user, flagged))
  def get(%User{}=user, flagged), do: repo().single(by_both_q(user, flagged))
  def get!(%User{}=user, flagged), do: repo().one(by_both_q(user, flagged))
  def by_flagger(%User{}=user), do: repo().all(by_flagger_q(user))
  def by_flagged(%User{}=user), do: repo().all(by_flagged_q(user))
  def by_any(%User{}=user), do: repo().all(by_any_q(user))

  def flag(%User{} = flagger, %{} = flagged) do
    with {:ok, flag} <- create(flagger, flagged) do
      # TODO: increment the flag count
      # TODO: put in admin(s) inbox feed
      # FeedActivities.publish(flagger, :flag, flagged)
      {:ok, flag}
    end
  end

  def unflag(%User{}=flagger, %{}=flagged) do
    delete_by_both(flagger, flagged) # delete the Flag
    Activities.delete_by_subject_verb_object(flagger, :flag, flagged) # delete the flag activity & feed entries (not needed unless publishing flags to feeds)
    # TODO: decrement the flag count
  end

  defp create(%{} = flagger, %{} = flagged) do
    changeset(flagger, flagged) |> repo().insert()
  end

  defp changeset(%{id: flagger}, %{id: flagged}) do
    Flag.changeset(%Flag{}, %{flagger_id: flagger, flagged_id: flagged})
  end

  @doc "Delete flags where i am the flagger"
  defp delete_by_flagger(%User{}=me), do: elem(repo().delete_all(by_flagger_q(me)), 1)

  @doc "Delete flags where i am the flagged"
  defp delete_by_flagged(%User{}=me), do: elem(repo().delete_all(by_flagged_q(me)), 1)

  @doc "Delete flags where i am the flagger or the flagged."
  defp delete_by_any(%User{}=me), do: elem(repo().delete_all(by_any_q(me)), 1)

  @doc "Delete flags where i am the flagger and someone else is the flagged."
  defp delete_by_both(%User{}=me, %{}=flagged), do: elem(repo().delete_all(by_both_q(me, flagged)), 1)

  def by_flagger_q(%User{id: id}) do
    from f in Flag,
      where: f.flagger_id == ^id,
      select: f.id
  end

  def by_flagged_q(%User{id: id}) do
    from f in Flag,
      where: f.flagged_id == ^id,
      select: f.id
  end

  def by_any_q(%User{id: id}) do
    from f in Flag,
      where: f.flagger_id == ^id or f.flagged_id == ^id,
      select: f.id
  end

  def by_both_q(%User{id: flagger}, %{id: flagged}), do: by_both_q(flagger, flagged)

  def by_both_q(flagger, flagged) when is_binary(flagger) and is_binary(flagged) do
    from f in Flag,
      where: f.flagger_id == ^flagger or f.flagged_id == ^flagged,
      select: f.id
  end

end
