defmodule Bonfire.Me.Users do
  @doc """
  A User is a logical identity within the system belonging to an Account.
  """
  import Bonfire.Me.Integration
  import Ecto.Query, only: [from: 2, limit: 2]
  alias ActivityPub.Actor
  alias Bonfire.Data.Identity.{Account, Named, User}
  alias Bonfire.Data.AccessControl.{Acl, Controlled, Circle, Grant, InstanceAdmin}
  alias Bonfire.Me.{Characters, Profiles, Users, Users.Queries}
  alias Bonfire.Boundaries
  alias Bonfire.Boundaries.{Acls, Circles, Stereotyped, Verbs}
  alias Bonfire.Federate.ActivityPub.Utils, as: APUtils
  alias Bonfire.Common.Utils
  alias Ecto.Changeset
  alias Pointers.{Changesets, ULID}
  use Arrows
  use Bonfire.Common.Utils

  @type changeset_name :: :create
  @type changeset_extra :: Account.t | :remote

  @search_type "Bonfire.Data.Identity.User"

  def context_module, do: User
  def federation_module, do: ["Person"]

  ### Queries

  def get_current(nil), do: nil
  def get_current(id) when is_binary(id), do: repo().one(Queries.current(id))

  def fetch_current(id), do: repo().single(Queries.current(id))

  def query([id: id], _opts \\ []) when is_binary(id), do: by_id(id)

  def by_id(id) when is_binary(id), do: repo().single(Queries.by_id(id))
  def by_id([id]), do: by_id(id)

  # FIXME: if the username is a valid ULID, it will actually go looking for the wrong thing and not find them.
  def by_username(username) when is_binary(username), do: repo().single(Queries.by_username_or_id(username))

  def by_username!(username) when is_binary(username), do: repo().one(Queries.by_username_or_id(username))
  def by_account(account) do
    if module_enabled?(Bonfire.Data.SharedUser) and module_enabled?(Bonfire.Me.SharedUsers) do
      Bonfire.Me.SharedUsers.by_account(account)
    else
      do_by_account(account)
    end
  end

  defp do_by_account(%Account{id: id}), do: by_account(id)
  defp do_by_account(account_id) when is_binary(account_id),
    do: repo().many(Queries.by_account(account_id))

  @doc """
  Used for switch-user functionality
  """
  def by_username_and_account(username, account_id) do
    with {:ok, user} <- repo().single(Queries.by_username_and_account(username, account_id)),
    # check if user isn't blocked instance-wide
    blocked? when blocked? !=true <- Bonfire.Boundaries.Blocks.is_blocked?(user, :ghost, :instance_wide) do
      {:ok, user}
    end
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

  def is_admin?(%User{} = user), do: Utils.e(user, :instance_admin, :is_instance_admin, false)
  def is_admin?(_), do: false

  ### Mutations

  ## Create

  # @spec create(params_or_changeset, extra :: changeset_extra) :: Changeset.t
  def create(params_or_changeset, extra \\ nil)
  def create(%Changeset{data: %User{}}=changeset, _extra) do
    debug(changeset, "changeset")
    with {:ok, user} <- repo().insert(changeset) do
      post_create(user)
    end
  end
  def create(params, extra) when not is_struct(params),
    do: create(changeset(:create, params, extra))

  defp post_create(%{} = user) do

    create_default_boundaries(user) #|> debug("created_default_boundaries")

    post_mutate(user)
  end

  defp post_mutate(%{} = user) do
    user = user |> repo().maybe_preload([:character, :profile])

    maybe_index_user(user)

    {:ok, user}
  end

  ## instance admin

  @doc "Grants a user superpowers."
  def make_admin(username) when is_binary(username) do
    by_username(username)
    ~> make_admin()
  end
  def make_admin(%User{}=user), do: update_is_admin(user, true)

  @doc "Revokes a user's superpowers."
  def revoke_admin(username) when is_binary(username) do
    by_username(username)
    ~> revoke_admin()
  end
  def revoke_admin(%User{}=user), do: update_is_admin(user, false)

  defp update_is_admin(%User{}=user, make_admin?) do
    user
    |> repo().preload(:instance_admin)
    |> Changeset.cast(%{instance_admin: %{is_instance_admin: make_admin?}}, [])
    |> Changeset.cast_assoc(:instance_admin)
    |> repo().update()
  end

  def get_only_in_account(%Account{id: id}) do
    q = limit(Queries.by_account(id), 2)
    repo().all(q)
    |> case do
         [solo] -> {:ok, solo}
         _ -> :error
       end
  end

  ## Update

  def update(%User{} = user, params, extra \\ nil) do
  # TODO: check who is doing the update (except if extra==:remote)
    repo().update(changeset(:update, user, params, extra))
    # |> IO.inspect
    ~> post_mutate()
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

  ### ActivityPub

  def by_ap_id(ap_id) do
    with {:ok, %{username: username}} = ActivityPub.Actor.get_cached_by_ap_id(ap_id) do
      by_username(username)
    end
  end

  def by_ap_id!(ap_id) do
    with %ActivityPub.Actor{} = actor <- ActivityPub.Actor.get_by_ap_id!(ap_id) do
      by_username!(actor.username)
    end
  end

  def ap_receive_activity(_creator, _activity, object) do
    debug(object, "Users.ap_receive_activity")
    Bonfire.Federate.ActivityPub.Adapter.maybe_create_remote_actor(Utils.e(object, :data, object))
  end

  @doc "Creates a remote user"
  def create_remote(params) do
    with {:ok, user} <- create(changeset(:create, %User{}, params, :remote)) do
      # debug(user)
      {:ok, user} #|> add_acl("public")
    end
  end

  # what is this? it is only referenced by the commented out call in the above function.
  # def add_acl(%{} = user, preset) do
  #   user # FIXME: can we do this in main create changeset?
  #     |> repo().maybe_preload(:controlled)
  #     |> User.changeset(%{})
  #     |> Bonfire.Boundaries.Acls.cast(user, preset)
  #     |> repo().update()
  # end

  @doc "Updates a remote user"
  def update_remote(user, params) do
    update(user, params, :remote)
  end

  def format_actor(user) do
    APUtils.format_actor(user, "Person")
  end


  ## Adapter callbacks

  def update_local_actor(%User{} = user, params) do
    with {:ok, user} <- update(user, params),
         actor <- format_actor(user) do
      {:ok, actor}
    end
  end

  def update_local_actor(actor, params) do
    with {:ok, user} <- by_username(actor.username) do
      update_local_actor(user, params)
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
    params
    |> User.changeset(user, ...)
    |> Changesets.put_assoc(:accounted, %{account_id: account.id})
    |> Changesets.put_assoc(:encircles, [%{circle_id: Circles.circles().local.id}])
    |> Changesets.put_assoc(:character, %{})
    |> Changesets.cast_assoc(:character, required: true, with: &Characters.changeset/2)
    |> Changeset.cast_assoc(:profile, required: true, with: &Profiles.changeset/2)
  end

  def changeset(:create, user, params, :remote) do
    User.changeset(user, params)
    |> Changesets.put_assoc(:encircles, [%{circle_id: Circles.circles().local.id}])
    |> Changesets.put_assoc(:character, %{})
    |> Changesets.cast_assoc(:character, required: true, with: &Characters.remote_changeset/2)
    |> Changeset.cast_assoc(:profile, with: &Profiles.changeset/2)
    |> Changeset.cast_assoc(:peered)
  end

  def changeset(:create, _user, _params, _) do
    {:error, "Not authenticated"}
  end

  def changeset(:update, user, params, _extra) do
    user = repo().preload(user, [:profile, character: [:actor]])

    # Ecto doesn't liked mixed keys so we convert them all to strings
    params = Utils.stringify_keys(params)
    
    # add the ID for update
    params = params
      |> Map.merge(%{"profile" => %{"id"=> user.id}}, fn _, a, b -> Map.merge(a, b) end)
      |> Map.merge(%{"character" => %{"id"=> user.id}}, fn _, a, b -> Map.merge(a, b) end)

    loc = params["profile"]["location"]
    if loc && loc !="" && module_enabled?(Bonfire.Geolocate.Geolocations) do
      Bonfire.Geolocate.Geolocations.thing_add_location(user, user, loc)
    end
    user
    |> User.changeset(params)
    |> Changeset.cast_assoc(:character, with: &Characters.changeset/2)
    |> Changeset.cast_assoc(:profile, with: &Profiles.changeset/2)
    |> debug("users update changeset")
  end

  defp put_character(changeset) do
    user_id = Changeset.get_field(changeset, :id)
    Changeset.put_assoc(changeset, :character, %{id: user_id})
  end

  def indexing_object_format(u) do
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
    object |> indexing_object_format() |> maybe_index() #|> debug
  end
  def maybe_index_user(_other), do: nil

  defp config(), do: Application.get_env(:bonfire_me, Users)

  # Reads fixtures in configuration and creates a default boundaries setup for a user
  defp create_default_boundaries(user) do
    user_default_boundaries = Boundaries.user_default_boundaries()
    #  |> debug("create_default_boundaries")
    circles = for {k, v} <- Map.fetch!(user_default_boundaries, :circles), into: %{} do
      {k, v
      |> Map.put(:id, ULID.generate())
      |> stereotype(Circles)}
    end
    acls = for {k, v} <- Map.fetch!(user_default_boundaries, :acls), into: %{} do
      {k, v
      |> Map.put(:id, ULID.generate())
      |> stereotype(Acls)}
    end
    grants =
      for {acl, entries}  <- Map.fetch!(user_default_boundaries, :grants),
          {circle, verbs} <- entries,
          verb            <- verbs do
        case verb do
          _ when is_atom(verb)   ->
            %{verb_id: Verbs.get_id!(verb), value: true}
          _ when is_binary(verb) ->
            %{verb_id: verb, value: true}
          {verb, v} when is_atom(verb) and is_boolean(v) ->
            %{verb_id: Verbs.get_id!(verb), value: v}
          {verb, v} when is_binary(verb) and is_boolean(v) ->
            %{verb_id: verb, value: v}
        end
        |> Map.merge(%{
          id:         ULID.generate(),
          acl_id:     default_acl_id(acls, acl),
          subject_id: default_subject_id(circles, user, circle),
        })
      end
    controlleds =
      for {:SELF, acls2}  <- Map.fetch!(user_default_boundaries, :controlleds),
          acl <- acls2 do
        %{id: user.id, acl_id: default_acl_id(acls, acl)}
      end
    circles =
      circles
      # |> dump("circles for #{e(user, :character, :username, nil)}")
      |> Map.values()
    acls =
      acls
      # |> dump("acls for #{e(user, :character, :username, nil)}")
      |> Map.values()
    named =
      (acls ++ circles)
      |> Enum.filter(&(&1[:name]))
      |> Enum.map(&Map.take(&1, [:id, :name]))
    stereotypes =
      (acls ++ circles)
      |> Enum.filter(&(&1[:stereotype_id]))
      |> Enum.map(&Map.take(&1, [:id, :stereotype_id]))
    # First the pointables
    repo().insert_all_or_ignore(Acl,    Enum.map(acls,    &Map.take(&1, [:id])))
    repo().insert_all_or_ignore(Circle, Enum.map(circles, &Map.take(&1, [:id])))
    repo().insert_all_or_ignore(Grant,  grants)
    # Then the mixins
    repo().insert_all_or_ignore(Named, named)
    repo().insert_all_or_ignore(Controlled, controlleds)
    repo().insert_all_or_ignore(Stereotyped, stereotypes)
    # * The ACLs and Circles must be deleted when the user is deleted.
    # * Grants will take care of themselves because they have a strong pointer acl_id.
    Boundaries.take_care_of!(acls ++ circles, user)
  end

  # support for create_default_boundaries/1
  defp stereotype(attrs, module) do
    case attrs[:stereotype] do
      nil -> attrs
      other ->
        attrs
        |> Map.put(:stereotype_id, module.get_id!(other))
        |> Map.delete(:stereotype)
    end
  end

  # support for create_default_boundaries/1
  defp default_acl_id(acls, acl_id) do
    with nil <- Map.get(acls, acl_id, %{})[:id],
         nil <- Acls.get_id(acl_id) do
      raise RuntimeError,
        message: "invalid acl given in new user boundaries config: #{inspect(acl_id)}"
    end
  end

  # support for create_default_boundaries/1
  defp default_subject_id(_circles, user, :SELF), do: user.id
  defp default_subject_id(circles, _user, circle_id) do
    with nil <- Map.get(circles, circle_id, %{})[:id],
         nil <- Circles.get_id(circle_id) do
      raise RuntimeError,
        message: "invalid circle given in new user boundaries config: #{inspect(circle_id)}"
    end
  end

  def delete(users) when is_list(users) do

  end

end
