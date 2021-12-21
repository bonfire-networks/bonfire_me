defmodule Bonfire.Me.Users.Boundaries do
  alias Bonfire.Data.Identity.User
  require Logger

  def maybe_make_visible_for(current_user, object, circle_ids \\ []), do: maybe_grant_access_to(current_user, object, circle_ids, :read_only)

  @doc "Grant access to an object to a list of circles + the user"
  def maybe_grant_access_to(current_user, object, circle_ids \\ [], access \\ :read_only)

  def maybe_grant_access_to(%{id: user_id}=current_user, object_id, circle_ids, access) when is_list(circle_ids) and is_binary(object_id) do

    grant_subjects = (circle_ids ++ [user_id]) #|> IO.inspect(label: "maybe_grant_access_to")

    Logger.debug("Boundaries grant #{inspect access} on object #{inspect object_id} to #{inspect circle_ids}")

    with {:ok, %{id: acl_id}} <- Bonfire.Me.Users.Acls.create(current_user, nil),# |> IO.inspect(label: "acled"),
    {:ok, _controlled} <- Bonfire.Boundaries.Controlleds.create(%{id: object_id, acl_id: acl_id}), #|> IO.inspect(label: "ctled"),
    {:ok, grant} <- Bonfire.Boundaries.Grants.grant(grant_subjects, acl_id, access) do # |> IO.inspect(label: "granted") do
      # IO.inspect(one_grant: grant)
      {:ok, :granted}
    else
      grants when is_list(grants) -> # FIXME
        # IO.inspect(many_grants: grants)
        {:ok, :granted}

      e -> {:error, e}
    end
  end

  def maybe_grant_access_to(current_user, %{id: object_id} = _object, circles, access) do
    maybe_grant_access_to(current_user, object_id, circles, access)
  end

  def maybe_grant_access_to(current_user, object, circle, access) when not is_list(circle) do
    maybe_grant_access_to(current_user, object, [circle], access)
  end

  def maybe_grant_access_to(user_or_account_id, object, circles, access) when is_binary(user_or_account_id) do
    with {:ok, user_or_account} <- Bonfire.Common.Pointers.get(user_or_account_id, skip_boundary_check: true) do
      maybe_grant_access_to(user_or_account, object, circles, access)
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
