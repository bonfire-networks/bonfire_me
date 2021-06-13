defmodule Bonfire.Me.Users.Boundaries do
  alias Bonfire.Data.Identity.User

  def maybe_make_visible_for(user, object, circle_ids \\ []), do: maybe_grant_access_to(user, object, circle_ids, :read_only)

  @doc "Grant access to an object to a list of circles + the user"
  def maybe_grant_access_to(user, object, circle_ids \\ [], access \\ :read_only)

  def maybe_grant_access_to(%User{id: user_id}=user, %{id: object_id} = _object, circle_ids, access) when is_list(circle_ids) do

    grant_subjects = (circle_ids ++ [user_id]) #|> IO.inspect(label: "grant_subjects")

    with {:ok, %{id: acl_id}} <- Bonfire.Me.Users.Acls.create(user, nil),
    {:ok, _controlled} <- Bonfire.Boundaries.Controlleds.create(%{id: object_id, acl_id: acl_id}),
    {:ok, grants} <- Bonfire.Boundaries.Grants.grant(grant_subjects, acl_id, access) do
      # IO.inspect(grants: grants)
      {:ok, :granted}
    else
      grants when is_list(grants) ->
        # IO.inspect(grants: grants)
        {:ok, :granted}

      e -> {:error, e}
    end
  end

  def maybe_grant_access_to(user, object, circle, access) do
    maybe_grant_access_to(user, object, [circle], access)
  end

  def maybe_grant_access_to(_, _, _, _), do: :skipped

end
