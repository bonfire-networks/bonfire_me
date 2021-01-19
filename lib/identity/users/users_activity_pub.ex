defmodule Bonfire.Me.Identity.Users.ActivityPub do
  alias Bonfire.Me.Identity.Users
  alias Bonfire.Data.ActivityPub.Peer
  alias Bonfire.Data.Identity.User
  alias Bonfire.Me.Identity.Users.Queries
  alias ActivityPub.Actor

  import Bonfire.Me.Integration
  import Pointers.Changesets

  def by_username(username) when is_binary(username),
    do: repo().single(Queries.by_username(username))

  @doc "Creates a remote user"
  def create(params, %Peer{id: id}) do
    Users.changeset(:create, %User{}, params, :remote)
    |> Changesets.change(peer_id: id)
    |> repo().insert()
  end

  @doc "Updates a remote user"
  def update(user, params) do
    Users.update(user, params, :remote)
  end

  defp format_actor(user) do
    user = Bonfire.Repo.preload(user, [:actor])
    ap_base_path = Bonfire.Common.Config.get(:ap_base_path, "/pub")
    id = Bonfire.Web.Endpoint.url() <> ap_base_path <> "/actors/#{user.character.username}"

    data = %{
      "type" => "Person",
      "id" => id,
      "inbox" => "#{id}/inbox",
      "outbox" => "#{id}/outbox",
      "followers" => "#{id}/followers",
      "following" => "#{id}/following",
      "preferredUsername" => user.character.username,
      "name" => user.profile.name,
      "summary" => Map.get(user.profile, :summary)
    }

    %Actor{
      id: user.id,
      data: data,
      keys: Bonfire.Common.Utils.maybe_get(user.actor, :signing_key),
      local: true,
      ap_id: id,
      pointer_id: user.id,
      username: user.character.username,
      deactivated: false
    }
  end

  ## Adapter callbacks

  def get_actor_by_username(username) do
    with {:ok, user} <- Users.ActivityPub.by_username(username),
         actor <- format_actor(user) do
      {:ok, actor}
    else
      _ ->
        {:error, :not_found}
    end
  end

  def update_local_actor(actor, params) do
    with {:ok, user} <- Users.ActivityPub.by_username(actor.username),
         {:ok, user} <-
           Users.ActivityPub.update(user, Map.put(params, :actor, %{signing_key: params.keys})),
         actor <- format_actor(user) do
      {:ok, actor}
    end
  end
end
