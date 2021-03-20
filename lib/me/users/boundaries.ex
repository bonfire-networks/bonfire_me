defmodule Bonfire.Me.Users.Boundaries do
  alias Bonfire.Data.Identity.User

  def maybe_grant_read_to_circles(%User{}=user, %{id: object_id} = _object, circle_ids) when is_list(circle_ids) do
    with {:ok, %{id: acl_id}} <- Bonfire.Me.Users.Acls.create(user, nil),
    {:ok, controlled} <- Bonfire.Boundaries.Controlleds.create(%{id: object_id, acl_id: acl_id}),
    {:ok, grants} <- Bonfire.Boundaries.Grants.grant(circle_ids, acl_id) do
      :ok
    end
  end
  def maybe_grant_read_to_circles(_, _, _), do: :skipped

end
