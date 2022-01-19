defmodule Bonfire.Me.Users do
  @doc """
  A User is a logical identity within the system belonging to an Account.
  """
  use OK.Pipe
  alias ActivityPub.Actor
  alias Bonfire.Data.Identity.{Account, Named, User}
  alias Bonfire.Data.AccessControl.{Acl, Circle, Grant, InstanceAdmin}
  alias Bonfire.Me.{Characters, Profiles, Users, Users.Queries}
  alias Bonfire.Boundaries
  alias Bonfire.Boundaries.{Acls, Circles, Stereotype, Verbs}
  alias Bonfire.Federate.ActivityPub.Utils, as: APUtils
  alias Bonfire.Common.Utils
  alias Ecto.Changeset
  alias Pointers.ULID
  import Bonfire.Me.Integration
  import Ecto.Query, only: [from: 2, limit: 2]

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
  def by_id([id]), do: by_id(id)

  def by_username(username) when is_binary(username), do: repo().single(Queries.by_username_or_id(username))

  def by_username!(username) when is_binary(username), do: repo().one(Queries.by_username_or_id(username))
  def by_account(account) do
    if Utils.module_enabled?(Bonfire.Data.SharedUser) and Utils.module_enabled?(Bonfire.Me.SharedUsers) do
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

  def is_admin(%User{} = user), do: Utils.e(user, :instance_admin, :is_instance_admin, false)
  def is_admin(_), do: false

  ### Mutations

  ## Create

  # @spec create(params_or_changeset, extra :: changeset_extra) :: Changeset.t
  def create(params_or_changeset, extra \\ nil)
  def create(%Changeset{data: %User{}}=changeset, _extra) do
    with {:ok, user} <- repo().insert(changeset) do
      create_default_boundaries(user)
      {:ok, post_mutate(user)}
    end
  end
  def create(params, extra) when not is_struct(params),
    do: create(changeset(:create, params, extra))

  defp post_mutate({:ok, object}), do: {:ok, post_mutate(object)}
  defp post_mutate(%{} = user) do
    user
    |> repo().maybe_preload([:character, :profile])
    |> maybe_index_user()
  end
  defp post_mutate(error), do: error

  ## instance admin

  @doc "Grants a user superpowers."
  def make_admin(username) when is_binary(username) do
    with {:ok, user} <- by_username(username) do
      make_admin(user)
    end
  end
  def make_admin(%User{}=user) do
    user
    |> repo().preload(:instance_admin)
    |> Changeset.cast(%{instance_admin: %{is_instance_admin: true}}, [])
    |> Changeset.cast_assoc(:instance_admin)
    |> repo().update!()
  end

  # this is where we are very careful to explicitly set all the things
  # a user should have but shouldn't have control over the input for.
  defp override(changeset, :create, %Account{}=account) do
    Changeset.cast changeset, %{
      accounted:      %{account_id: account.id},
      encircles:      [%{circle_id: Circles.circles().local.id}]
    }, []
  end

  defp override(changeset, :create, :remote) do
    Changeset.cast changeset, %{
      encircles: [%{circle_id: Circles.circles().activity_pub.id}]
    }, []
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
    IO.inspect(object, label: "Users.ap_receive_activity")
    Bonfire.Federate.ActivityPub.Adapter.maybe_create_remote_actor(Utils.e(object, :data, object))
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

  # TODO: we need to make sure that only user input that we want is given
  def changeset(:create, user, params, %Account{}=account) do
    User.changeset(user, params)
    |> override(:create, account)
    |> Changeset.cast_assoc(:character, required: true, with: &Characters.changeset/2)
    |> Changeset.cast_assoc(:profile, required: true, with: &Profiles.changeset/2)
    |> Changeset.cast_assoc(:accounted)
    |> Changeset.cast_assoc(:instance_admin)
    # |> Changeset.cast_assoc(:like_count)
    |> Changeset.cast_assoc(:encircles)
    # |> IO.inspect(label: "Users.changeset(:create, ...")
  end

  def changeset(:create, user, params, :remote) do
    User.changeset(user, params)
    |> override(:create, :remote)
    |> Changeset.cast_assoc(:character, required: true, with: &Characters.remote_changeset/2)
    |> Changeset.cast_assoc(:profile, with: &Profiles.changeset/2)
    |> Changeset.cast_assoc(:encircles)
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
      |> Map.merge(%{"profile" => %{"id"=> user.profile.id}}, fn _, a, b -> Map.merge(a, b) end)
      |> Map.merge(%{"character" => %{"id"=> user.character.id}}, fn _, a, b -> Map.merge(a, b) end)


    if params["profile"]["location"] && params["profile"]["location"] !="" && Utils.module_enabled?(Bonfire.Geolocate.Geolocations) do
      Bonfire.Geolocate.Geolocations.thing_add_location(user, user, params["profile"]["location"])
    end

    user
    |> User.changeset(params)
    |> Changeset.cast_assoc(:character, with: &Characters.changeset/2)
    |> Changeset.cast_assoc(:profile, with: &Profiles.changeset/2)
    # |> IO.inspect(label: "users update changeset")
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
    object |> indexing_object_format() |> maybe_index()
    object
  end
  def maybe_index_user(other), do: other

  defp config(), do: Application.get_env(:bonfire_me, Users)

  defp create_default_boundaries(user) do
    config = Keyword.fetch!(config(), :default_boundaries)
    circles = for {k, v} <- Map.fetch!(config, :circles), into: %{} do
      {k, v
      |> Map.put(:id, ULID.generate())
      |> stereotype(Circles)}
    end
    acls = for {k, v} <- Map.fetch!(config, :acls), into: %{} do
      {k, v
      |> Map.put(:id, ULID.generate())
      |> stereotype(Acls)}
    end
    # my_stereotypes = Map.fetch!(acls, :my_stereotypes)
    grants =
      for {acl, entries}  <- Map.fetch!(config, :grants),
          {circle, verbs} <- entries,
          verb            <- verbs do
        extra = case verb do
          _ when is_atom(verb)   -> %{verb_id: Verbs.get_id!(verb), value: true}
          _ when is_binary(verb) -> %{verb_id: verb, value: true}
          {verb, v} when is_atom(verb) and is_boolean(v) ->
            %{verb_id: Verbs.get_id!(verb), value: v}
          {verb, v} when is_binary(verb) and is_boolean(v) ->
            %{verb_id: verb, value: v}
        end
        Map.merge(%{
          id:         ULID.generate(),
          acl_id:     default_acl_id(acls, acl),
          subject_id: default_subject_id(circles, user, circle),
        }, extra)
      end
    circles = Map.values(circles)
    acls = Map.values(acls)
    # grants = grants ++
    #   for thing <- acls ++ circles,
    #       verb  <- [:see, :read] do
    #     %{id:         ULID.generate(),
    #       acl_id:     thing.id,
    #       subject_id: user.id,
    #       verb_id:    Verbs.get_id!(verb),
    #       value:      true}
    #   end
    named =
      (acls ++ circles)
      |> Enum.filter(&(&1[:name]))
      |> Enum.map(&Map.take(&1, [:id, :name]))
    stereotypes =
      (acls ++ circles)
      |> Enum.filter(&(&1[:stereotype]))
      |> Enum.map(&Map.take(&1, [:id, :name]))
    # First the pointables
    repo().insert_all(Acl,    Enum.map(acls,    &Map.take(&1, [:id])))
    repo().insert_all(Circle, Enum.map(circles, &Map.take(&1, [:id])))
    repo().insert_all(Grant,  grants)
    # Then the mixins
    repo().insert_all(Named,  named)
    repo().insert_all(Stereotype, stereotypes)
    Boundaries.take_care_of!([user] ++ acls ++ circles ++ grants, user)
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

end
