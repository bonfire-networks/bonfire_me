defmodule Bonfire.Me.Users.Boundaries do
  alias Bonfire.Data.Identity.User

  def maybe_make_visible_for(user, object, circle_ids \\ []), do: maybe_grant_access_to(user, object, circle_ids, :read_only)

  @doc "Grant access to an object to a list of circles + the user"
  def maybe_grant_access_to(user, object, circle_ids \\ [], access \\ :read_only)

  def maybe_grant_access_to(%User{id: user_id}=user, %{id: object_id} = _object, circle_ids, access) when is_list(circle_ids) do
    with {:ok, %{id: acl_id}} <- Bonfire.Me.Users.Acls.create(user, nil),
    {:ok, controlled} <- Bonfire.Boundaries.Controlleds.create(%{id: object_id, acl_id: acl_id}),
    {:ok, grants} <- Bonfire.Boundaries.Grants.grant(circle_ids ++ [user_id], acl_id, access) do
        :ok
    end
  end

  def maybe_grant_access_to(user, object, _, access) do
    maybe_grant_access_to(user, object, [], access) # add creator to grants
  end

  def maybe_grant_access_to(_, _, _, _), do: :skipped

end
