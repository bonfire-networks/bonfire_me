defmodule Bonfire.Me.Users do
  @doc """
  A User is a logical identity within the system belonging to an Account.
  """
  use OK.Pipe
  alias Bonfire.Data.Identity.{Account, User}
  alias Bonfire.Data.AccessControl.InstanceAdmin

  alias Bonfire.Me.Characters
  alias Bonfire.Me.Users.Queries
  alias Bonfire.Me.Profiles
  alias Bonfire.Boundaries.Circles

  # alias Pointers.Changesets
  alias Bonfire.Common.Utils
  alias Ecto.Changeset
  import Bonfire.Me.Integration

  alias ActivityPub.Actor
  alias Bonfire.Federate.ActivityPub.Utils, as: APUtils

  import Bonfire.Me.Integration
  import Ecto.Query, only: [from: 2]

  @type changeset_name :: :create
  @type changeset_extra :: Account.t | :remote

  @search_type "Bonfire.Data.Identity.User"

  def context_module, do: User
  def federation_module, do: ["Person"]

  ### Queries

  def get_current(nil), do: nil
  def get_current(id) when is_binary(id), do: repo().one(Queries.current(id))

  def fetch_current(id), do: repo().single(Queries.current(id))

  def by_id(id) when is_binary(id), do: repo().single(Queries.by_id(id))

  def by_username(username) when is_binary(username), do: repo().single(Queries.by_username_or_id(username))

  def by_account(account) do
    if Utils.module_enabled?(Bonfire.Data.SharedUser) do
      Bonfire.Me.SharedUsers.by_account(account)
    else
      do_by_account(account)
    end
  end

  defp do_by_account(%Account{id: id}), do: by_account(id)
  defp do_by_account(account_id) when is_binary(account_id),
    do: repo().many(Queries.by_account(account_id))

  def by_username_and_account(username, account_id) do
    repo().single(Queries.by_username_and_account(username, account_id))
  end

  def search(search) do
    Utils.maybe_apply(Bonfire.Search, :search_by_type, [search, @search_type], &none/2) || search_db(search)
  end
  defp none(_, _), do: nil

  def search_db(search), do: repo().many(Queries.search(search))
  def list, do: repo().many(Queries.list())
  def list_admins(), do: repo().many(Queries.admins())

  def flatten(user) do
    user
    |> Map.merge(user, user.profile)
    |> Map.merge(user, user.character)
  end

  def is_admin(%User{} = user) do
    Utils.e(user, :instance_admin, :is_instance_admin, false)
  end

  ### Mutations

  ## Create

  # @spec create(params_or_changeset, extra :: changeset_extra) :: Changeset.t
  def create(params_or_changeset, extra \\ nil)
  def create(%Changeset{data: %User{}}=changeset, _extra) do
    repo().insert(changeset)
    |> post_mutate()
  end
  def create(params, extra) when not is_struct(params) do
    repo().insert(changeset(:create, %User{}, params, extra))
    |> post_mutate()
  end

  defp post_mutate({:ok, object}), do: {:ok, post_mutate(object)}
  defp post_mutate(%{} = user) do
    user
    |> repo().maybe_preload([:character, :profile])
    |> maybe_index_user()
  end
  defp post_mutate(error), do: error

  ## instance admin

  def make_admin(%InstanceAdmin{} = admin),
    do: InstanceAdmin.changeset(admin, %{is_instance_admin: true}) |> repo().update!()

  def make_admin(%User{instance_admin: admin}), do: make_admin(admin)

  # this is where we are very careful to explicitly set all the things
  # a user should have but shouldn't have control over the input for.
  defp override(changeset, :create, %Account{}=account) do
    Changeset.cast changeset, %{
      accounted:    %{account_id: account.id},
      # like_count:   %{liker_count: 0,    liked_count: 0},
      instance_admin:    %{is_instance_admin: is_first_user?()}, # first user to be created is automatically admin # TODO: make this more secure (eg. only active if an env flag is set)
      encircles:    [%{circle_id: Circles.circles().local}]
    }, []
  end

  defp override(changeset, :create, :remote) do
    Changeset.cast changeset, %{
      encircles: [%{circle_id: Circles.circles().activity_pub}]
    }, []
  end

  def is_first_user? do
    Queries.count() <1
  end


  ## Update

  def update(%User{} = user, params, extra \\ nil) do
  # TODO: check who is doing the update (except if extra==:remote)
    repo().update(changeset(:update, user, params, extra))
    # |> IO.inspect
    |> post_mutate()
  end


  ## Delete

  # def delete(%User{}=user) do
  #   preloads =
  #     [:actor, :character, :follow_count, :like_count, :profile, :self] ++
  #     [accounted: [:account]]
  #   user = repo().preload(user, preloads)
  #   with :ok         <- delete_caretaken(user),
  #        {:ok, user} <- delete_mixins(user) do
  #     {:ok, user}
  #   end
  # end

  # # TODO: what must we chase down?
  # # * acls
  # # * accesses
  # # * grants
  # # * posts
  # # * feeds
  # defp delete_caretaken(user) do
  #   :ok
  # end

  ### ActivityPub

  def by_ap_id(ap_id) do
    with {:ok, %{username: username}} = ActivityPub.Actor.get_cached_by_ap_id(ap_id) do
      by_username(username)
    end
  end

  @doc "Creates a remote user"
  def create_remote(params) do
    changeset(:create, %User{}, params, :remote)
    |> repo().insert()
  end

  @doc "Updates a remote user"
  def update_remote(user, params) do
    update(user, params, :remote)
  end

  def format_actor(user) do
    APUtils.format_actor(user, "Person")
  end

  def create_remote_actor(actor) do

    actor_object = ActivityPub.Object.get_by_ap_id(actor.ap_id)

    icon_url = APUtils.maybe_fix_image_object(actor.data["icon"])
    image_url = APUtils.maybe_fix_image_object(actor.data["image"])

    with {:ok, user} <- repo().transact_with(fn ->
      with  {:ok, peer} =  Bonfire.Federate.ActivityPub.Peers.get_or_create(actor),
            {:ok, user} <- create_remote(%{
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
      icon_id = APUtils.maybe_create_icon_object(icon_url, user)
      image_id = APUtils.maybe_create_image_object(image_url, user)

      with {:ok, updated_user} <- update_remote(user, %{"profile" => %{"icon_id" => icon_id, "image_id" => image_id}}) do
        {:ok, updated_user}
      else _ ->
        {:ok, user}
      end
    end
  end

  ## Adapter callbacks

  def update_local_actor(actor, params) do
    with {:ok, user} <- by_username(actor.username),
         {:ok, user} <-
           update(user, Map.put(params, :actor, %{signing_key: params.keys})),
         actor <- format_actor(user) do
      {:ok, actor}
    end
  end

  ## Changesets ############


  @spec changeset(
    name :: changeset_name,
    params :: map,
    extra :: Account.t | :remote
  ) :: Changeset.t

  @spec changeset(
    name :: changeset_name,
    user :: User.t,
    params :: map,
    extra :: Account.t | :remote
  ) :: Changeset.t

  def changeset(name , user \\ %User{}, params, extra)

  def changeset(:create, user, params, %Account{}=account) do
    User.changeset(user, params)
    |> override(:create, account)
    |> Changeset.cast_assoc(:character, required: true, with: &Characters.changeset/2)
    |> Changeset.cast_assoc(:profile, required: true, with: &Profiles.changeset/2)
    |> Changeset.cast_assoc(:accounted)
    |> Changeset.cast_assoc(:instance_admin)
    # |> Changeset.cast_assoc(:like_count)
    |> Changeset.cast_assoc(:encircles)
  end

  def changeset(:create, user, params, :remote) do
    User.changeset(user, params)
    |> override(:create, :remote)
    |> Changeset.cast_assoc(:character, required: true, with: &Characters.remote_changeset/2)
    |> Changeset.cast_assoc(:profile, with: &Profiles.changeset/2)
    # |> Changeset.cast_assoc(:like_count)
    |> Changeset.cast_assoc(:encircles)
    |> Changeset.cast_assoc(:peered)
  end


  def changeset(:update, user, params, _extra) do
    user = repo().preload(user, [:profile, character: [:actor]])

    # Ecto doesn't liked mixed keys so we convert them all to strings
    params = Utils.stringify_keys(params)

    # add the ID for update
    params = params
      |> Map.merge(%{"profile" => %{"id"=> user.profile.id}}, fn _, a, b -> Map.merge(a, b) end)
      |> Map.merge(%{"character" => %{"id"=> user.character.id}}, fn _, a, b -> Map.merge(a, b) end)

    params =
      if Map.get(user, :actor) do
        params
        |> Map.merge(%{"character" => %{"actor"=> user.character.actor}}, fn _, a, b -> Map.merge(a, b) end)
      else
        params
      end

    if params["profile"]["location"] && params["profile"]["location"] !="" && Utils.module_enabled?(Bonfire.Geolocate.Geolocations) do
      Bonfire.Geolocate.Geolocations.thing_add_location(user, user, params["profile"]["location"])
    end

    user
    |> User.changeset(params)
    |> Changeset.cast_assoc(:character, with: &Characters.changeset/2)
    |> Changeset.cast_assoc(:profile, with: &Profiles.changeset/2)
  end

  def indexing_object_format(u) do

    # IO.inspect(obj)

    %{
      "id" => u.id,
      "index_type" => @search_type,
      # "url" => path(obj),
      "profile" => Bonfire.Me.Profiles.indexing_object_format(u.profile),
      "character" => Bonfire.Me.Characters.indexing_object_format(u.character),
    } #|> IO.inspect
  end

  # TODO: less boilerplate
  def maybe_index_user(object) when is_map(object) do
    object |> indexing_object_format() |> maybe_index()
    object
  end
  def maybe_index_user(other), do: other

end
