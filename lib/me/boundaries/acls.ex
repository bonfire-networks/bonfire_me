defmodule Bonfire.Me.Acls do
  use Bonfire.Common.Utils

  alias Bonfire.Data.AccessControl.Acl
  alias Bonfire.Data.Identity.User

  alias Bonfire.Boundaries.Acls
  import Bonfire.Boundaries.Queries
  import Bonfire.Me.Integration
  import Ecto.Query
  import EctoSparkles
  alias Ecto.Changeset

  def cast(changeset, creator, preset) do
    base = base_acls(preset)
    custom_grants = reply_to_grants(changeset, preset) ++ mentions_grants(changeset, preset)
    acl = case custom_grants do
      [] ->
        changeset
        |> Changeset.cast(%{controlled: base}, [])
        |> Changeset.cast_assoc(:controlled)
      _ ->
        # TODO: cast a new acl. this is slightly tricky because we
        # need to insert the acl with cast_assoc(:acl) while taking the rest
        # of the controlleds from the base maps
        changeset
        |> Changeset.cast(%{controlled: base}, [])
        |> Changeset.cast_assoc(:controlled)
    end
  end

  # when the user picks a preset, this maps to a set of base acls
  defp base_acls(preset) do
    acls = case preset do
      "public" -> [:guests_may_see, :locals_may_reply, :i_may_administer]
      "local"  -> [:locals_may_reply, :i_may_administer]
      _        -> [:i_may_administer]
    end
    |> Enum.map(&(%{acl_id: Acls.get_id!(&1)}))
  end

  # defp acls(changeset, preset) do
  #   case mentions_grants(changeset, preset) do
  #     [] -> base_acls(preset)
  #     grants -> [%{acl: %{grants: grants}} | base_acls(preset)]
  #   end
  # end

  defp reply_to_grants(changeset, preset) do

    debug(Utils.e(changeset, :changes, :replied, :replying_to, []), "TODO: creators of reply_to should be added to a new ACL")

    case preset do
      "public" ->
        # TODO include all
        []
      "local" ->
        # TODO include only if local
        []
      _ ->
      []
    end
  end

  defp mentions_grants(changeset, preset) do
    debug(Utils.e(changeset, :changes, :post_content, :changes, :mentions, []), "TODO: mentions/tags should be added to a new ACL")

    case preset do
      "public" ->
        # TODO include all
        []
      "mentions" ->
        # TODO include all
        []
      "local" ->
        # TODO include only if local
        []
      _ ->
      []
    end
  end


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
  defp changeset(:create, attrs, opts, %{id: id}) do
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
