defmodule Bonfire.Me.Users.ActivityPub do
  alias Bonfire.Me.Users
  alias Bonfire.Data.Identity.User
  alias ActivityPub.Actor
  alias Bonfire.Federate.ActivityPub.Utils

  import Bonfire.Me.Integration
  import Ecto.Query, only: [from: 2]

  def federation_module, do: ["Person"]

  def by_username(username) when is_binary(username),
    do: Users.by_username(username)

  def by_ap_id(ap_id) do
    with {:ok, %{username: username}} = ActivityPub.Actor.get_cached_by_ap_id(ap_id) do
      by_username(username)
    end
  end

  @doc "Creates a remote user"
  def create(params) do
    Users.changeset(:create, %User{}, params, :remote)
    |> repo().insert()
  end

  @doc "Updates a remote user"
  def update(user, params) do
    Users.update(user, params, :remote)
  end

  defp format_actor(user) do
    user = Bonfire.Repo.preload(user, [:actor, profile: [:image, :icon]])
    ap_base_path = Bonfire.Common.Config.get(:ap_base_path, "/pub")
    id = Bonfire.Common.URIs.base_url() <> ap_base_path <> "/actors/#{user.character.username}"

    icon = Utils.maybe_create_image_object_from_path(Bonfire.Files.IconUploader.remote_url(user.profile.icon))
    image = Utils.maybe_create_image_object_from_path(Bonfire.Files.ImageUploader.remote_url(user.profile.image))

    data = %{
      "type" => "Person",
      "id" => id,
      "inbox" => "#{id}/inbox",
      "outbox" => "#{id}/outbox",
      "followers" => "#{id}/followers",
      "following" => "#{id}/following",
      "preferredUsername" => user.character.username,
      "name" => user.profile.name,
      "summary" => Map.get(user.profile, :summary),
      "icon" => icon,
      "image" => image
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

  def create_remote_actor(actor) do

    actor_object = ActivityPub.Object.get_by_ap_id(actor.ap_id)

    icon_url = Bonfire.Federate.ActivityPub.Utils.maybe_fix_image_object(actor.data["icon"])
    image_url = Bonfire.Federate.ActivityPub.Utils.maybe_fix_image_object(actor.data["image"])

    with {:ok, user} <- repo().transact_with(fn ->
      with  {:ok, peer} =  Bonfire.Federate.ActivityPub.Peers.get_or_create(actor),
            {:ok, user} <- create(%{
              character: %{
                username: actor.username
              },
              profile: %{
                name: actor.data["name"],
                summary: actor.data["summary"]
              },
              peered: %{
                peer_id: peer.id,
                canonical_uri: actor.ap_id
              }
            }),
            {:ok, _object} <- ActivityPub.Object.update(actor_object, %{pointer_id: user.id}) do
        {:ok, user}
      end
    end) do

      # after creating the user, in case of timeouts downloading the images
      icon_id = Bonfire.Federate.ActivityPub.Utils.maybe_create_icon_object(icon_url, user)
      image_id = Bonfire.Federate.ActivityPub.Utils.maybe_create_image_object(image_url, user)

      with {:ok, updated_user} <- update(user, %{"profile" => %{"icon_id" => icon_id, "image_id" => image_id}}) do
        {:ok, updated_user}
      else _ ->
        {:ok, user}
      end
    end
  end

  ## Adapter callbacks

  def get_actor_by_username(username) do
    with {:ok, user} <- by_username(username),
         actor <- format_actor(user) do
      {:ok, actor}
    else
      _ ->
        {:error, :not_found}
    end
  end

  def get_actor_by_id(id) do
    with {:ok, user} <- Users.by_id(id),
         actor <- format_actor(user) do
      {:ok, actor}
    else
      _ ->
        {:error, :not_found}
    end
  end

  def get_actor_by_ap_id(ap_id) do
    with {:ok, user} <- by_ap_id(ap_id),
         actor <- format_actor(user) do
      {:ok, actor}
    else
      _ ->
        {:error, :not_found}
    end
  end

  def update_local_actor(actor, params) do
    with {:ok, user} <- by_username(actor.username),
         {:ok, user} <-
           Users.ActivityPub.update(user, Map.put(params, :actor, %{signing_key: params.keys})),
         actor <- format_actor(user) do
      {:ok, actor}
    end
  end

  def maybe_create_remote_actor(actor) do
    case by_username(actor.username) do
      {:ok, _} -> :ok
      {:error, _} -> create_remote_actor(actor)
    end
  end

  def get_follower_local_ids(actor) do
    with {:ok, user} <- by_username(actor.username) do
      Bonfire.Social.Follows.follower_by_followed(user)
    end
  end

  def get_following_local_ids(actor) do
    with {:ok, user} <- by_username(actor.username) do
      Bonfire.Social.Follows.by_follower(user)
    end
  end
end
