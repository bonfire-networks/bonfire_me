defmodule Bonfire.Me.Grants do

  import Bonfire.Me.Integration
  import Ecto.Query
  import EctoSparkles
  import Bonfire.Boundaries.Queries
  require Logger

  alias Bonfire.Common.Utils
  alias Bonfire.Common.Config
  alias Ecto.Changeset
  alias Bonfire.Data.AccessControl.Grant
  alias Bonfire.Data.Identity.User
  alias Bonfire.Data.AccessControl.Accesses
  alias Bonfire.Boundaries.{Circles, Grants}

  @doc """
  Grant takes three parameters:
  - subject_id:  who we are granting access to
  - acl_id: what (list of) things we are granting access to
  - value: true, false, or nil
  - verb_id: which verb/action
  """
  def grant(subject_id, acl_id, verb, value, opts \\ [])

  def grant(subject_ids, acl_id, verb, value, opts) when is_list(subject_ids), do: subject_ids |> Circles.circle_ids() |> Enum.map(&grant(&1, acl_id, verb, value, opts)) #|> IO.inspect(label: "mapped") # TODO: optimise?

  def grant(subject_id, acl_id, verbs, value, opts) when is_list(verbs), do: Enum.map(verbs, &grant(subject_id, acl_id, &1, value, opts)) #|> IO.inspect(label: "mapped") # TODO: optimise?

  def grant(subject_id, acl_id, verb, value, opts) when is_atom(verb) and not is_nil(verb) do
    Logger.info("Me.Grants - lookup verb #{inspect verb}")
    grant(subject_id, acl_id, Config.get(:verbs)[verb][:id], value, opts)
  end

  def grant(subject_id, acl_id, verb_id, value, opts) when is_binary(subject_id) and is_binary(acl_id) and is_binary(verb_id) do
    create(
      %{
        subject_id: subject_id,
        acl_id:     acl_id,
        verb_id:  verb_id,
        value: value
      },
      opts
    )
  end

  def grant(subject_id, acl_id, access, value, opts) when not is_nil(subject_id) do
    subject_id |> Circles.circle_ids() |> grant(acl_id, access, value, opts)
  end

  def grant(_, _, _, _, _), do: nil


  ## invariants:

  ## * All a user's GRANTs will have the user as an administrator but it
  ##   will be hidden from the user

  def create(attrs, opts) do
    changeset(:create, attrs, opts)
    |> repo().insert()
    # |> IO.inspect(label: "Me.Grants - granted")
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
