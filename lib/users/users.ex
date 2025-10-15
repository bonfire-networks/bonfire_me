defmodule Bonfire.Me.Users do
  @moduledoc """
  A User represents a visible identity within the system belonging to an Account (see `Bonfire.Me.Accounts`) and having a Profile (see `Bonfire.Me.Profiles`) and a Character identified by a username (see `Bonfire.Me.Characters`).
  """

  use Arrows
  use Bonfire.Common.Utils
  alias Bonfire.Me.Integration
  import Integration
  import Ecto.Query, only: [limit: 2, select: 2]
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

  @behaviour Bonfire.Common.ContextModule
  def schema_module, do: User
  def query_module, do: Bonfire.Me.Users.Queries

  @behaviour Bonfire.Federate.ActivityPub.FederationModules
  def federation_module, do: ["Person", "Author"]

  ### Queries

  @doc """
  Gets the current user by ID.

  ## Examples

      iex> Bonfire.Me.Users.get_current(nil)
      nil

      > Bonfire.Me.Users.get_current("user_id")
      %Bonfire.Data.Identity.User{}
  """
  def get_current(nil), do: nil
  def get_current(id) when is_binary(id), do: repo().maybe_one(Queries.current(id))
  def get_current(nil, _), do: nil

  def get_current(id, account_id) when is_binary(id),
    do: repo().maybe_one(Queries.current(id, account_id))

  @doc """
  Fetches the current user by ID.

  ## Examples

      > Bonfire.Me.Users.fetch_current("user_id")
      %Bonfire.Data.Identity.User{}
  """
  def fetch_current(id), do: repo().single(Queries.current(id))

  # def query(filters, opts \\ [])
  # def query([id: id], opts) when is_binary(id), do: by_id(id, opts)
  # def query(filters, opts) when is_binary(term) do
  #   Queries.query(filters, opts)
  # end

  @doc """
  Gets a user by ID.

  ## Examples

      > Bonfire.Me.Users.by_id("user_id")
      %Bonfire.Data.Identity.User{}

      > Bonfire.Me.Users.by_id(["user_id"])
      %Bonfire.Data.Identity.User{}
  """
  def by_id(id, opts \\ [])

  def by_id(id, opts) when is_binary(id),
    do: repo().single(Queries.by_id(id, opts))

  def by_id([id], opts), do: by_id(id, opts)

  @doc """
  Gets a user by username.

  ## Examples

      > Bonfire.Me.Users.by_username("username")
      %Bonfire.Data.Identity.User{}
  """
  # FIXME: if the username looks like a valid ULID, it will actually go looking for the wrong thing and not find them.
  def by_username(username, opts \\ []) when is_binary(username) do
    # info(self(), username)
    # info(repo())
    Queries.by_username_or_id(username, opts[:preload])
    # |> debug()
    |> repo().single()
  end

  @doc """
  Gets a user by canonical URI.

  ## Examples

      > Bonfire.Me.Users.by_canonical_uri("http://example.com")
      %Bonfire.Data.Identity.User{}
  """
  def by_canonical_uri(uri) when is_binary(uri) do
    Queries.by_canonical_uri(uri)
    # |> info(repo())
    |> repo().single()

    # |> info(uri)
  end

  @doc """
  Gets a user by username, raising an error if not found.

  ## Examples

      > Bonfire.Me.Users.by_username!("username")
      %Bonfire.Data.Identity.User{}
  """
  def by_username!(username, opts \\ []) when is_binary(username),
    do: repo().one(Queries.by_username_or_id(username, opts))

  @doc """
  Gets users by account.

  ## Examples

      > Bonfire.Me.Users.by_account(%Bonfire.Data.Identity.Account{id: "account_id"})
      [%Bonfire.Data.Identity.User{}]

      > Bonfire.Me.Users.by_account!("account_id")
      [%Bonfire.Data.Identity.User{}]
  """
  def by_account(account) do
    if module = maybe_module(Bonfire.Me.SharedUsers) do
      module.by_account(account)
    else
      do_by_account(account)
    end
  end

  def by_account!(account) do
    by_account(account)
    |> check_active!()
  end

  defp do_by_account(account_id),
    do: Queries.by_account(account_id) |> repo().many()

  def ids_by_account(account_id),
    do: Queries.by_account(account_id) |> repo().pluck(:id)

  @doc """
  Gets a user by username or user ID and account ID, useful for switch-user functionality. 

  Will throw an error if any of the account's users is blocked instance-wide by admins.

  ## Examples

      > Bonfire.Me.Users.by_user_and_account("username", "account_id")
      {:ok, %Bonfire.Data.Identity.User{}}
  """
  def by_user_and_account(username_or_user_id, account_id) do
    # check that none of the account's users have been disabled by instance admin - FIXME: can we do it without querying the full list of users?
    check_active!(ids_by_account(account_id))

    with {:ok, user} <-
           repo().single(Queries.by_user_and_account(username_or_user_id, account_id)) do
      # check if user isn't blocked instance-wide (already done above)
      #  {:ok, _} <- check_active(user) do
      {:ok, user}
    end
  end

  @doc """
  Checks if a user is active.

  ## Examples

      > Bonfire.Me.Users.is_active?(user)
        
  """
  def is_active?(user), do: !Bonfire.Boundaries.Blocks.is_blocked?(user, :ghost, :instance_wide)

  @doc """
  Checks if users are active.

  ## Examples

      iex> Bonfire.Me.Users.check_active([user1])
      [{:ok, %Bonfire.Data.Identity.User{}}]

      iex> Bonfire.Me.Users.check_active(user)
      {:ok, %Bonfire.Data.Identity.User{}}
  """
  # Enum.map(users, &check_active/1) 
  def check_active(users) when is_list(users),
    do: Bonfire.Boundaries.Blocks.reject_blocked(users, :ghost, :instance_wide)

  def check_active(user) do
    if is_active?(user), do: {:ok, user}, else: {:error, :inactive_user}
  end

  # Enum.map(users, &check_active!/1)
  def check_active!(users) when is_list(users),
    do: Bonfire.Boundaries.Blocks.check_blocked!(users, :ghost, :instance_wide, :inactive_user)

  def check_active!(user) when is_map(user) or is_binary(user) do
    if is_active?(user), do: user, else: throw(:inactive_user)
  end

  def check_active!(other), do: other

  @doc """
  Searches for users.

  ## Examples

      > Bonfire.Me.Users.search("username")
      [%Bonfire.Data.Identity.User{}]
  """
  def search(search, opts \\ []) do
    opts =
      to_options(opts)
      # TEMP: to speed things up
      |> Keyword.put_new(:skip_boundary_check, true)

    Utils.maybe_apply(
      Bonfire.Search,
      :search_by_type,
      [search, User, opts],
      &none/2
    ) ||
      search_query(search, opts) |> repo().many()
  end

  defp none(_, _), do: []

  @doc """
  Query for searching for users.

  ## Examples

      > Bonfire.Me.Users.search_query("search_term")
      %Ecto.Query{}
  """
  def search_query(search, opts \\ []), do: Queries.search(search, opts)

  # def list_all(show \\ :local), do: repo().many(Queries.list(show))
  def list_admins(opts \\ []), do: repo().many(Queries.admins(opts))

  def list_boundarised_query(opts) do
    # Note: users who said they don't want to be publicly discoverable in settings will be filtered based on boundaries (i.e. not shown to guests)
    Queries.list(Keyword.get(opts, :show, :local))
    # Queries.query(filters, opts)
    |> boundarise(user.id, opts ++ [verbs: [:see]])
  end

  def list(opts) do
    opts = to_options(opts)

    # Note: users who said they don't want to be publicly discoverable in settings will be filtered based on boundaries (i.e. not shown to guests)
    list_boundarised_query(opts)
    |> repo().many()
  end

  def list_paginated(opts \\ []) do
    opts =
      to_options(opts)
      |> debug()

    list_boundarised_query(opts)
    # return a page of items (reverse chronological) + pagination metadata
    |> repo().many_paginated(opts)
  end

  def flatten(user) do
    user
    |> Map.merge(user, user.profile)
    |> Map.merge(user, user.character)
  end

  ### Mutations
  ## Create

  # @spec create(params_or_changeset, extra :: changeset_extra) :: Changeset.t
  def create(params_or_changeset, opts \\ [])

  def create(%Changeset{data: %User{}} = changeset, opts) do
    clean_opts = to_options(opts)

    make_admin? =
      (!(opts == :remote or clean_opts[:local] == false) and Config.env() != :test and
         is_first_user?())
      |> debug("maybe_make_admin?")

    if !clean_opts[:skip_spam_check],
      do:
        Profiles.spam_check!(
          "#{get_attr(changeset, :profile, :name)} #{get_attr(changeset, :profile, :summary)}",
          clean_opts
        )

    repo_insert_fun = (clean_opts[:repo_insert_fun] || :insert) |> debug()

    with {:ok, user} <-
           repo().transact_with(fn -> apply(repo(), repo_insert_fun, [changeset]) end) do
      after_creation(user, make_admin?, opts)
    end
  end

  def create(params, extra) when not is_struct(params) do
    changeset(:create, params, extra)
    |> create()
  end

  defp after_creation(%{} = user, make_admin?, opts) do
    clean_opts =
      to_options(opts)
      |> debug("opts")

    if module = maybe_module(Bonfire.Boundaries.Scaffold.Users),
      do: module.create_default_boundaries(user, opts)

    case opts[:open_id_provider] do
      {provider, provider_token} ->
        maybe_apply(Bonfire.OpenID.Client, :link_provider_token, [
          user,
          provider,
          provider_token
        ])

      _ ->
        :ok
    end

    user =
      if not is_nil(clean_opts[:undiscoverable]),
        do:
          Bonfire.Common.Settings.put(
            [Bonfire.Me.Users, :undiscoverable],
            clean_opts[:undiscoverable],
            current_user: user
          )
          |> current_user(),
        else: user

    user =
      if clean_opts[:unindexable] do
        Bonfire.Common.Settings.put([Bonfire.Search.Indexer, :modularity], :disabled,
          current_user: user
        )
        |> current_user()
      else
        user
      end

    if make_admin? do
      make_admin(user)
      ~> after_mutation()
    else
      after_mutation(user)
    end
  end

  defp after_mutation(%{} = user, previous_user \\ nil) do
    user = repo().maybe_preload(user, [:character, :profile])

    maybe_index_user(user, previous_user)

    {:ok, user}
  end

  defp get_attr(changeset, assoc, key) do
    ed(changeset, :changes, assoc, :changes, key, nil)
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
      Bonfire.Boundaries.Scaffold.Instance.admin_circle()
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
      Bonfire.Boundaries.Scaffold.Instance.admin_circle()
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

  def update(%User{} = user, params, extra \\ []) do
    # TODO: check who is doing the update (except if extra==:remote)

    changeset = changeset(:update, user, params, extra)

    Profiles.spam_check!(
      "#{get_attr(changeset, :profile, :name)} #{get_attr(changeset, :profile, :summary)}",
      to_options(extra) ++ [current_user: user]
    )

    changeset
    # |> debug("csss")
    |> repo().update()
    |> debug("updatted")
    ~> after_mutation(user)
    ~> Bonfire.Federate.ActivityPub.Adapter.local_actor_updated(extra != :remote)
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

  # Call `enqueue_delete/1` instead
  @doc false
  def delete(user, opts \\ [])

  def delete(users, opts) when is_list(users) do
    Enum.map(users, &delete(&1, opts))
    |> List.first()
  end

  def delete(%{} = user, opts) do
    assocs =
      [
        :follow_count,
        :like_count,
        :settings,
        :self,
        :accounted,
        :encircles,
        :actor,
        :character,
        :profile
        # profile: [:icon, :image] # handled by Media.delete
      ]
      |> debug("user_delete_assocs")

    # TO CHECK: deletion of user's edges (likes/follows/etc), and boundaries (circles/ACLs/etc)
    # TO CHECK: deletion of user's objects (based on caretaker) and activities

    user = repo().maybe_preload(user, profile: [:icon, :image])

    # user = repo().maybe_preload(user, assocs)
    Bonfire.Common.Utils.maybe_apply(
      Bonfire.Social.Objects,
      :maybe_generic_delete,
      [
        User,
        user,
        Keyword.merge(opts,
          current_user: user,
          delete_associations: assocs,
          delete_caretaken: true,
          delete_media: [e(user, :profile, :icon, nil), e(user, :profile, :banner, nil)]
        )
        # |> debug("maybe_generic_delete_opts")
      ]
    )
    |> debug("attempted to delete user with generic_delete")

    # Bonfire.Social.Objects.maybe_generic_delete(
    #   User,
    #   user,
    #   opts ++
    #     [
    #       current_user: user,
    #       delete_associations: assocs,
    #       delete_caretaken: true
    #     ]
    # )
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

    Bonfire.Common.Utils.maybe_apply(
      Bonfire.Federate.ActivityPub.Adapter,
      :maybe_create_remote_actor,
      [e(object, :data, object)]
    )
  end

  @doc "Creates a remote user"
  def create_remote(params, opts \\ []) do
    with {:ok, user} <- create(changeset(:create, %User{}, params, :remote), opts) do
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
    Bonfire.Common.Utils.maybe_apply(
      Bonfire.Federate.ActivityPub.AdapterUtils,
      :format_actor,
      [user, "Person"]
    )
  end

  ## Adapter callbacks

  def update_local_actor(%User{} = user, params) do
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
    existing_users_for_account = ids_by_account(account)

    # check that we can still create more users for this account
    if Config.get(
         [Bonfire.Me.Users, :max_per_account],
         4
       ) <= length(existing_users_for_account),
       do:
         throw(
           "You have reached the maximum number of user profiles you can create. Please contact your instance admins."
         )

    # check that none of the account's users have been disabled by instance admin - FIXME: can we do it without querying the full list of users?
    check_active!(existing_users_for_account)

    params
    # |> debug("params")
    |> User.changeset(user, ...)
    # |> debug("initial cs")
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

    # FIXME: Tag with Geolocation # TODO: move to Profiles changeset?
    case e(params["profile"], :location, nil) do
      location when is_binary(location) and location != "" ->
        maybe_apply(Bonfire.Geolocate.Geolocations, :thing_add_location, [user, user, location])

      # TODO: also set user's timezone?
      # TzWorld.timezone_at(%Geo.Point{_})

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
      "index_type" => Types.module_to_str(User),
      # "url" => path(obj),
      "profile" => Bonfire.Me.Profiles.indexing_object_format(u.profile),
      "character" => Bonfire.Me.Characters.indexing_object_format(u.character)
    }
    |> debug()
  end

  def maybe_index_user(object, previous \\ nil)

  def maybe_index_user(object, previous) when is_map(object) do
    # check discovery settings
    user = repo().maybe_preload(previous || object, :settings)

    if Bonfire.Common.Settings.get([Bonfire.Me.Users, :undiscoverable], nil, current_user: user) do
      maybe_apply(Bonfire.Search, :maybe_index, [object, "private", user], user)
    else
      maybe_apply(Bonfire.Search, :maybe_index, [object, "public", user], user)
    end
  end

  def maybe_index_user(_other, _), do: nil

  def count(show \\ :local), do: repo().one(Queries.count(show))

  def maybe_count(show \\ :local) do
    if Settings.get([__MODULE__, :public_count], true, :instance),
      do: count(show)
  end

  def is_first_user? do
    # Cache the result to avoid repeated COUNT queries during tests
    case Process.get(:is_first_user_cached) do
      false ->
        false

      _nil_or_true ->
        result = count() < 1
        Process.put(:is_first_user_cached, result)
        result
    end
  end

  @doc """
  Clears cached values for testing. Call this in test setup/teardown.
  """
  def clear_cache do
    Process.delete(:is_first_user_cached)
  end

  def make_user(attrs, account, opts \\ []) do
    with {:ok, user} <- changeset(:create, attrs, account) |> create(opts) do
      {:ok, Map.put(user, :settings, nil)}
    end
  end

  def get_or_create_service_user(
        service_character_username,
        data \\ %{summary: nil, website: nil, location: nil}
      ) do
    with {:ok, user} <-
           Bonfire.Me.Users.by_username(Characters.clean_username(service_character_username)) do
      user
    else
      {:error, :not_found} ->
        create_service_character(service_character_username, data)
    end
  end

  def get_or_create_service_character(
        service_character_id,
        service_character_username,
        bio \\ nil
      ) do
    with {:ok, user} <- Bonfire.Me.Users.by_id(service_character_id) do
      user
    else
      {:error, :not_found} ->
        create_service_character(service_character_username, %{
          id: service_character_id,
          summary: bio,
          website: nil,
          location: nil
        })
    end
  end

  defp create_service_character(service_character_username, data) do
    Bonfire.Me.Fake.fake_user!(
      service_character_username,
      data,
      request_before_follow: true,
      undiscoverable: true,
      skip_spam_check: true
    )
  end
end
