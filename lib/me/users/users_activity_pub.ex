defmodule Bonfire.Me.Users.ActivityPub do
  alias Bonfire.Me.Users
  alias Bonfire.Data.ActivityPub.Peer
  alias Bonfire.Data.Identity.User
  alias Bonfire.Me.Users.Queries
  alias ActivityPub.Actor
  alias Ecto.Changeset

  import Bonfire.Me.Integration
  import Ecto.Query

  def by_username(username) when is_binary(username),
    do: repo().single(Queries.by_username(username))

  @doc "Creates a remote user"
  def create(params, %Peer{id: id}) do
    Users.changeset(:create, %User{}, params, :remote)
    |> Changeset.change(peer_id: id)
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

  def peer_url_query(url) do
    from p in Peer,
    where: p.ap_base_uri == ^url
  end

  defp get_or_create_peer(actor) do
    uri = URI.parse(actor.data["id"])
    ap_base_url = uri.scheme <> "://" <> uri.host

    case repo().single(peer_url_query(ap_base_url)) do
      {:ok, peer} -> {:ok, peer}
      {:error, _} ->
        params = %{ap_base_uri: ap_base_url, display_hostname: uri.host}
        repo().insert(Peer.changeset(%Peer{}, params))
    end
  end

  def create_remote_actor(actor) do
    attrs = %{
      name: actor.data["name"],
      username: actor.username,
      summary: actor.data["summary"]
    }

    {:ok, peer} = get_or_create_peer(actor)
    actor_object = ActivityPub.Object.get_by_ap_id(actor.ap_id)

    repo().transact_with(fn ->
      with {:ok, user} <- create(attrs, peer),
           {:ok, _object} <- ActivityPub.Object.update(actor_object, %{pointer_id: user.id}) do
        {:ok, user}
      end
    end)
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

  def maybe_create_remote_actor(actor) do
    case Users.by_username(actor.username) do
      {:ok, _} -> :ok
      {:error, _} -> create_remote_actor(actor)
    end
  end
end
