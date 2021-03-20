defmodule Bonfire.Me.Users.Boundaries do
  alias Bonfire.Data.Identity.User

  @doc "Grant access to an object to a list of circles + the user"
  def maybe_grant_read_to_circles(user, object, circle_ids \\ [])

  def maybe_grant_read_to_circles(%User{id: user_id}=user, %{id: object_id} = _object, circle_ids) when is_list(circle_ids) do
    with {:ok, %{id: acl_id}} <- Bonfire.Me.Users.Acls.create(user, nil),
    {:ok, controlled} <- Bonfire.Boundaries.Controlleds.create(%{id: object_id, acl_id: acl_id}),
    {:ok, grants} <- Bonfire.Boundaries.Grants.grant(circle_ids ++ [user_id], acl_id) do
      :ok
    end
  end

  def maybe_grant_read_to_circles(user, object, _) do
    maybe_grant_read_to_circles(user, object, []) # add creator to grants
  end

  def maybe_grant_read_to_circles(_, _, _), do: :skipped

end
