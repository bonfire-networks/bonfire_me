defmodule Bonfire.Me.Users.Grants do

  alias Bonfire.Data.AccessControl.Grant
  alias Bonfire.Data.Identity.User

  import Bonfire.Boundaries.{Grants, Queries}
  import Bonfire.Me.Integration
  import Ecto.Query
  import EctoSparkles
  alias Bonfire.Common.Utils

  ## invariants:

  ## * All a user's GRANTs will have the user as an administrator but it
  ##   will be hidden from the user

  def create(attrs, opts) do
    changeset(:create, attrs, opts)
    |> repo().insert()
  end

  def changeset(:create, attrs, opts) do
    changeset(:create, attrs, opts, Keyword.fetch!(opts, :current_user))
  end

  defp changeset(:create, attrs, opts, :system), do: Grants.changeset(attrs)
  defp changeset(:create, attrs, opts, %User{id: id}) do
    Changeset.cast(%Grant{}, %{caretaker: %{caretaker_id: id}}, [])
    |> Grants.changeset(attrs)
  end

  @doc """
  Lists the grants permitted to see.
  """
  def list(opts) do
    list_q(opts)
    |> preload(:named)
    |> repo().many()
  end

  def list_q(opts), do: list_q(Keyword.fetch!(opts, :current_user), opts)
  defp list_q(:system, opts), do: from(grant in Grant, as: :grant)
  defp list_q(%User{}, opts), do: boundarise(list_q(:system, opts), grant.id, opts)

  @doc """
  Lists the grants we are the registered caretakers of that we are
  permitted to see. If any are created without permitting the
  user to see them, they will not be shown.
  """
  def list_my(%{}=user), do: repo().many(list_my_q(user))

  @doc "query for `list_my`"
  def list_my_q(%{id: user_id}=user) do
    list_q(user)
    |> join(:inner, [grant: grant], caretaker in assoc(grant, :caretaker), as: :caretaker)
    |> where([caretaker: caretaker], caretaker.caretaker_id == ^user_id)
  end

end
