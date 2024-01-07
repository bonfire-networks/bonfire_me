defmodule Bonfire.Me.Users do
  @doc """
  A User is a logical identity within the system belonging to an Account.
  """
  use Arrows
  use Bonfire.Common.Utils
  import Bonfire.Me.Integration
  import Ecto.Query, only: [limit: 2]
  import Bonfire.Boundaries.Queries
  # alias ActivityPub.Actor
  alias Bonfire.Data.Identity.Account
  alias Bonfire.Data.Identity.User

  alias Bonfire.Me.Characters
  alias Bonfire.Me.Profiles
  alias Bonfire.Me.Users.Queries
  alias Bonfire.Me.Accounts

  alias Bonfire.Boundaries.Circles
  alias Bonfire.Federate.ActivityPub.AdapterUtils
  alias Bonfire.Common.Utils
  alias Ecto.Changeset
  alias Needle.Changesets
  # alias Needle.ULID

  @type changeset_name :: :create
  @type changeset_extra :: Account.t() | :remote

  @search_type "Bonfire.Data.Identity.User"

  @behaviour Bonfire.Common.ContextModule
  def schema_module, do: User
  def query_module, do: __MODULE__

  @behaviour Bonfire.Federate.ActivityPub.FederationModules
  def federation_module, do: ["Person", "Author"]

  @remote_fetcher "1ACT1V1TYPVBREM0TESFETCHER"
  def remote_fetcher, do: @remote_fetcher

  ### Queries

  def get_current(nil), do: nil
  def get_current(id) when is_binary(id), do: repo().maybe_one(Queries.current(id))
  def get_current(nil, _), do: nil

  def get_current(id, account_id) when is_binary(id),
    do: repo().maybe_one(Queries.current(id, account_id))

  def fetch_current(id), do: repo().single(Queries.current(id))

  def query([id: id], opts \\ []) when is_binary(id), do: by_id(id, opts)

  def by_id(id, opts \\ [])

  def by_id(id, opts) when is_binary(id),
    do: repo().single(Queries.by_id(id, opts))

  def by_id([id], opts), do: by_id(id, opts)

  # FIXME: if the username is a valid ULID, it will actually go looking for the wrong thing and not find them.
  def by_username(username, opts \\ []) when is_binary(username) do
    # info(self(), username)
    # info(repo())
    Queries.by_username_or_id(username, opts[:preload])
    |> debug()
    |> repo().single()
  end

  def by_canonical_uri(uri) when is_binary(uri) do
    Queries.by_canonical_uri(uri)
    # |> info(repo())
    |> repo().single()

    # |> info(uri)
  end

  def by_username!(username) when is_binary(username),
    do: repo().one(Queries.by_username_or_id(username))

  def by_account(account) do
    if module_enabled?(Bonfire.Data.SharedUser) do
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
    with {:ok, user} <-
           repo().single(Queries.by_username_and_account(username, account_id)),
         # check if user isn't blocked instance-wide
         {:ok, _} <- check_active(user) do
      {:ok, user}
    end
  end

  def is_active?(user), do: !Bonfire.Boundaries.Blocks.is_blocked?(user, :ghost, :instance_wide)

  def check_active(users) when is_list(users), do: Enum.map(users, &check_active/1)

  def check_active(user) do
    if is_active?(user), do: {:ok, user}, else: {:error, :inactive_user}
  end

  def check_active!(users) when is_list(users), do: Enum.map(users, &check_active!/1)

  def check_active!(user) when is_map(user) or is_binary(user) do
    if is_active?(user), do: user, else: throw(:inactive_user)
  end

  def check_active!(other), do: other

  def search(search) do
    Utils.maybe_apply(
      Bonfire.Search,
      :search_by_type,
      [search, @search_type],
      &none/2
    ) || search_db(search)
  end

  defp none(_, _), do: nil

  def search_db(search), do: repo().many(Queries.search(search))

  def list_all(show \\ :local), do: repo().many(Queries.list(show))
  def list_admins(), do: repo().many(Queries.admins())

  def list(opts) do
    opts = to_options(opts)

    # Note: users who said they don't want to be publicly discoverable in settings will be filtered based on boundaries (i.e. not shown to guests)
    Queries.list(Keyword.get(opts, :show, :local))
    |> boundarise(user.id, opts ++ [verbs: [:see]])
    |> repo().many()
  end

  def list_paginated(filters, opts \\ []) do
    Queries.query(filters, opts)
    # return a page of items (reverse chronological) + pagination metadata
    |> Integration.many(opts[:paginate?], opts)
  end

  def flatten(user) do
    user
    |> Map.merge(user, user.profile)
    |> Map.merge(user, user.character)
  end

  ### Mutations
  ## Create

  # @spec create(params_or_changeset, extra :: changeset_extra) :: Changeset.t
  def create(params_or_changeset, extra \\ nil)

  def create(%Changeset{data: %User{}} = changeset, extra) do
    add_to_admin_circle? =
      (extra != :remote and Config.env() != :test and is_first_user?())
      |> debug("maybe_make_admin?")

    with {:ok, user} <-
           changeset
           |> repo().insert() do
      if add_to_admin_circle?, do: add_to_admin_circle(user)
      after_creation(user, extra)
    end
  end

  def create(params, extra) when not is_struct(params) do
    changeset(:create, params, extra)
    |> create()
  end

  defp after_creation(%{} = user, opts) do
    opts =
      to_options(opts)
      |> debug("opts")

    if module_enabled?(Bonfire.Boundaries),
      do: Bonfire.Boundaries.Users.create_default_boundaries(user, opts)

    user =
      if not is_nil(opts[:undiscoverable]),
        do:
          Bonfire.Common.Settings.put([Bonfire.Me.Users, :undiscoverable], opts[:undiscoverable],
            current_user: user
          )
          |> current_user(),
        else: user

    user =
      if opts[:unindexable] do
        Bonfire.Common.Settings.put([Bonfire.Search.Indexer, :modularity], :disabled,
          current_user: user
        )
        |> current_user()
      else
        user
      end

    after_mutation(user)
  end

  defp after_mutation(%{} = user) do
    user = repo().maybe_preload(user, [:character, :profile])

    maybe_index_user(user)

    {:ok, user}
  end

  ## instance admin

  @doc "Grants a user superpowers."
  def make_admin(username) when is_binary(username) do
    by_username(username)
    ~> make_admin()
  end

  def make_admin(%User{} = user) do
    with {:ok, account} <- Accounts.update_is_admin(user, true) do
      add_to_admin_circle(user)
      {:ok, Map.put(user, :account, account)}
    end
  end

  defp add_to_admin_circle(user) do
    Bonfire.Boundaries.Circles.add_to_circles(
      user,
      Bonfire.Boundaries.Fixtures.admin_circle()
    )
  end

  @doc "Revokes a user's superpowers."
  def revoke_admin(username) when is_binary(username) do
    by_username(username)
    ~> revoke_admin()
  end

  def revoke_admin(%User{} = user) do
    with {:ok, _account} <- Accounts.update_is_admin(user, false) do
      remove_from_admin_circle(user)

      {:ok,
       user
       |> Map.put(
         :account,
         Map.put(e(user, :account, %{}), :instance_admin, nil)
       )
       |> Map.put(:instance_admin, nil)}
    end
  end

  defp remove_from_admin_circle(user) do
    Bonfire.Boundaries.Circles.remove_from_circles(
      user,
      Bonfire.Boundaries.Fixtures.admin_circle()
    )
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
    changeset(:update, user, params, extra)
    |> debug("csss")
    |> repo().update()
    |> debug("updatted")
    ~> after_mutation()
    ~> Bonfire.Federate.ActivityPub.Adapter.update_local_actor_cache()
  end

  ## Delete

  def enqueue_delete(%{} = user) when is_struct(user) do
    user
    |> repo().maybe_preload([:character])
    |> Bonfire.Me.DeleteWorker.enqueue_delete()
  end

  def enqueue_delete(user) when is_binary(user) do
    enqueue_delete(
      get_current(user) ||
        Bonfire.Boundaries.load_pointer(user, include_deleted: true, skip_boundary_check: true)
    )
  end

  @doc "Use `enqueue_delete/1` instead"
  def delete(user, _opts \\ [])

  def delete(users, _) when is_list(users) do
    Enum.map(users, &delete/1)
    |> List.first()
  end

  def delete(%{} = user, _) do
    assocs = [
      :actor,
      :character,
      :follow_count,
      :like_count,
      :profile,
      :settings,
      :self,
      :accounted
    ]

    # TODO: delete edges (likes/follows/etc), and boundaries (circles/ACLs/etc)
    # TODO: delete user's objects (based on caretaker) and activities

    # user = repo().maybe_preload(user, assocs)

    Bonfire.Social.Objects.maybe_generic_delete(User, user,
      current_user: user,
      delete_associations: assocs,
      delete_caretaken: true
    )
  end

  # def delete(users) when is_list(users) do
  # end
  ### ActivityPub

  def by_ap_id(ap_id) do
    with {:ok, %{username: username}} <- ActivityPub.Actor.get_cached(ap_id: ap_id) do
      by_username(username)
    end
  end

  def by_ap_id!(ap_id) do
    with %ActivityPub.Actor{} = actor <- ActivityPub.Actor.get_cached!(ap_id: ap_id) do
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
      # |> add_acl("public")
      {:ok, user}
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
  def update_remote_actor(user, params) do
    user
    # |> repo().reload() # to avoid stale struct errors
    |> update(params, :remote)
  end

  def format_actor(user) do
    AdapterUtils.format_actor(user, "Person")
  end

  ## Adapter callbacks

  def update_local_actor(%User{} = user, params) do
    info(params)

    with {:ok, user} <- update(repo().reload(user), params),
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
          extra :: Account.t() | :remote
        ) :: Changeset.t()

  @spec changeset(
          name :: changeset_name,
          user :: User.t(),
          params :: map,
          extra :: Account.t() | :remote
        ) :: Changeset.t()

  def changeset(name, user \\ %User{}, params, extra)

  def changeset(action, user, %{keys: keys} = params, extra) when not is_nil(keys) do
    # for AP library
    changeset(
      action,
      user,
      params
      |> deep_merge(%{character: %{actor: %{signing_key: keys}}})
      |> Map.drop([:keys]),
      extra
    )
  end

  def changeset(:create, user, params, %Account{} = account) do
    # check that none of the account's users have been disabled by instance admin
    by_account(account)
    |> check_active!()

    params
    |> debug("params")
    |> User.changeset(user, ...)
    |> debug("initial cs")
    |> Changesets.put_assoc!(:accounted, %{account_id: account.id})
    |> Changesets.put_assoc!(:encircles, [
      %{circle_id: Circles.get_id!(:local)}
    ])
    |> Changesets.put_assoc!(:character, %{})
    |> Changesets.cast_assoc(:character,
      required: true,
      with: &Characters.changeset/2
    )
    |> Changeset.cast_assoc(:profile,
      required: true,
      with: &Profiles.changeset/2
    )
    |> debug("full cs")
  end

  def changeset(:create, user, params, :remote) do
    params
    |> debug("chhhs")
    |> User.changeset(user, ...)
    |> Changesets.put_assoc!(:encircles, [
      %{circle_id: Circles.get_id!(:activity_pub)}
    ])
    |> Changesets.put_assoc!(:character, %{})
    |> Changesets.cast_assoc(:character,
      required: true,
      with: &Characters.remote_changeset/2
    )
    |> Changeset.cast_assoc(:profile, with: &Profiles.changeset_simple/2)
    |> Changeset.cast_assoc(:peered)
  end

  def changeset(:create, _user, _params, _) do
    {:error, "Not authenticated"}
  end

  def changeset(:update, user, params, _extra) do
    user = repo().preload(user, [:profile, character: [:actor]])

    # Ecto doesn't liked mixed keys so we convert them all to strings
    # TODO: use atoms instead?
    params = Enums.stringify_keys(params, true)

    # add the ID for update
    params =
      params
      # |> Map.merge(%{"id" => user.id})
      |> Map.merge(%{"profile" => %{"id" => user.id}}, fn _, a, b ->
        Map.merge(a, b)
      end)
      |> Map.merge(%{"character" => %{"id" => user.id}}, fn _, a, b ->
        Map.merge(a, b)
      end)

    # FIXME: Tag with Geolocation
    case e(params["profile"], :location, nil) do
      location when is_binary(location) and location != "" ->
        maybe_apply(Bonfire.Geolocate.Geolocations, :thing_add_location, [user, user, location])

      _ ->
        user
    end
    |> debug("location added?")

    Ecto.Changeset.cast(user, params, [])
    # |> info()
    |> Changeset.cast_assoc(:character, with: &Characters.changeset/2)
    |> Changeset.cast_assoc(:profile, with: &Profiles.changeset/2)

    # |> debug("users update changeset")
  end

  # defp put_character(changeset) do
  #   user_id = Needle.Changesets.get_field(changeset, :id)
  #   Changeset.put_assoc(changeset, :character, %{id: user_id})
  # end

  def indexing_object_format(u) do
    %{
      "id" => u.id,
      "index_type" => @search_type,
      # "url" => path(obj),
      "profile" => Bonfire.Me.Profiles.indexing_object_format(u.profile),
      "character" => Bonfire.Me.Characters.indexing_object_format(u.character)
    }

    # |> IO.inspect
  end

  # TODO: less boilerplate
  def maybe_index_user(object) when is_map(object) do
    # |> debug
    # defp config(), do: Application.get_env(:bonfire_me, Users)

    object |> indexing_object_format() |> maybe_index()
  end

  def maybe_index_user(_other), do: nil

  def count(show \\ :local), do: repo().one(Queries.count(show))

  def maybe_count(show \\ :local) do
    if Settings.get([__MODULE__, :public_count], true, :instance),
      do: count(show)
  end

  def is_first_user? do
    count() < 1
  end
end
