defmodule Bonfire.Me.Boundaries do
  alias Bonfire.Data.Identity.User
  alias Bonfire.Common.Utils
  require Logger

  @visibility_verbs [:see, :read]

  def maybe_compose_ad_hoc_acl(base_acl, user) do
  end

  def maybe_make_visible_for(current_user, object, circle_ids \\ []), do: maybe_grant_access_to(current_user, object, circle_ids, @visibility_verbs)

  @doc "Grant verbs to an object to a list of circles + the user"
  def maybe_grant_access_to(current_user, object, circle_ids \\ [], verbs \\ @visibility_verbs)

  def maybe_grant_access_to(%{id: current_user_id} = current_user, object_id, circle_ids, verbs) when is_list(circle_ids) and is_binary(object_id) do

    opts = [current_user: current_user]
    grant_subjects = Utils.ulid(circle_ids ++ [current_user]) #|> IO.inspect(label: "maybe_grant_access_to")

    Logger.debug("Boundaries grant #{inspect verbs} on object #{inspect object_id} to #{inspect circle_ids}")

    with {:ok, %{id: acl_id}} <- Bonfire.Me.Acls.create(opts),# |> IO.inspect(label: "acled"),
    {:ok, _controlled} <- Bonfire.Boundaries.Controlleds.create(%{id: object_id, acl_id: acl_id}), #|> IO.inspect(label: "ctled"),
    {:ok, grant} <- Bonfire.Me.Grants.grant(grant_subjects, acl_id, verbs, true, opts) do
      # IO.inspect(one_grant: grant)
      {:ok, :granted}
    else
      grants when is_list(grants) -> # TODO: check for failures?
        # IO.inspect(many_grants: grants)
        {:ok, :granted}

      e -> {:error, e}
    end
  end

  def maybe_grant_access_to(current_user, %{id: object_id} = _object, circles, verbs) do
    maybe_grant_access_to(current_user, object_id, circles, verbs)
  end

  def maybe_grant_access_to(current_user, object, circle, verbs) when not is_list(circle) do
    maybe_grant_access_to(current_user, object, [circle], verbs)
  end

  def maybe_grant_access_to(user_or_account_id, object, circles, verbs) when is_binary(user_or_account_id) do
    with {:ok, user_or_account} <- Bonfire.Common.Pointers.get(user_or_account_id, skip_boundary_check: true) do
      maybe_grant_access_to(user_or_account, object, circles, verbs)
    else _ ->
      Logger.warn("Boundaries.maybe_grant_access_to expected a user or account (or an ID of the same) as first param, got #{inspect user_or_account_id}")
      :skipped
    end
  end

  def maybe_grant_access_to(_, _, _, _) do
    Logger.warn("Boundaries.maybe_grant_access_to didn't receive an expected pattern in params")
    :skipped
  end

end
