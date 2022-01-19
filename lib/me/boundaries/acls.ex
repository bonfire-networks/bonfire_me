defmodule Bonfire.Me.Users.Acls do

  alias Bonfire.Data.AccessControl.Acl
  alias Bonfire.Data.Identity.User

  alias Bonfire.Boundaries.Acls
  import Bonfire.Boundaries.Queries
  import Bonfire.Me.Integration
  import Ecto.Query
  import EctoSparkles
  alias Ecto.Changeset
  alias Bonfire.Common.Utils

  ## invariants:

  ## * All a user's ACLs will have the user as an administrator but it
  ##   will be hidden from the user

  def create(attrs \\ %{}, opts) do
    changeset(:create, attrs, opts)
    |> repo().insert()
  end

  def changeset(:create, attrs, opts) do
    changeset(:create, attrs, opts, Keyword.fetch!(opts, :current_user))
  end

  defp changeset(:create, attrs, opts, :system), do: Acls.changeset(attrs)
  defp changeset(:create, attrs, opts, %User{id: id}) do
    Changeset.cast(%Acl{}, %{caretaker: %{caretaker_id: id}}, [])
    |> Acls.changeset(attrs)
  end

  @doc """
  Lists the ACLs permitted to see.
  """
  def list(opts) do
    list_q(opts)
    |> preload(:named)
    |> repo().many()
  end

  def list_q(opts), do: list_q(Keyword.fetch!(opts, :current_user), opts)
  defp list_q(:system, opts), do: from(acl in Acl, as: :acl)
  defp list_q(%User{}, opts), do: boundarise(list_q(:system, opts), acl.id, opts)

  @doc """
  Lists the ACLs we are the registered caretakers of that we are
  permitted to see. If any are created without permitting the
  user to see them, they will not be shown.
  """
  def list_my(%{}=user), do: repo().many(list_my_q(user))

  @doc "query for `list_my`"
  def list_my_q(%{id: user_id}=user) do
    list_q(user)
    |> join(:inner, [acl: acl], caretaker in assoc(acl, :caretaker), as: :caretaker)
    |> where([caretaker: caretaker], caretaker.caretaker_id == ^user_id)
  end

end
