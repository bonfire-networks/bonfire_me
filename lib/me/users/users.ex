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

  @type changeset_name :: :create
  @type changeset_extra :: Account.t | :remote

  ### Queries

  def get_current(nil), do: nil
  def get_current(id) when is_binary(id), do: repo().one(Queries.current(id))

  def fetch_current(id), do: repo().single(Queries.current(id))

  def by_id(id), do: get_flat(Queries.by_id(id))

  def by_username(username), do: get_flat(Queries.by_username(username))

  def by_account(account) do
    if Utils.module_exists?(Bonfire.Data.SharedUser) do
      Bonfire.Me.SharedUsers.by_account(account)
    else
      do_by_account(account)
    end
  end

  defp do_by_account(%Account{id: id}), do: by_account(id)
  defp do_by_account(account_id) when is_binary(account_id),
    do: repo().all(Queries.by_account(account_id))

  def for_switch_user(username, account_id) do
    get_flat(Queries.for_switch_user(username, account_id))
  end

  def list, do: repo().all(Queries.with_mixins())
  def list_admins(), do: repo().all(Queries.admins())

  def flatten(user) do
    user
    |> Map.merge(user, user.profile)
    |> Map.merge(user, user.character)
  end

  def get_flat(query) do
    repo().single(query)
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
  end
  def create(params, extra) when not is_struct(params) do
    repo().insert(changeset(:create, %User{}, params, extra))
  end

  ## instance admin

  def make_admin(%{id: id}),
    do: admin_changeset(%{id: id, is_instance_admin: true}) |> repo().upsert

  # this is where we are very careful to explicitly set all the things
  # a user should have but shouldn't have control over the input for.
  defp override(changeset, changeset_type, extra \\ nil)

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
    Bonfire.Me.Users.Queries.count() <1
  end


  ## Update

  def update(%User{} = user, params, extra \\ nil) do
  # TODO: check who is doing the update (except if extra==:remote)
    repo().update(changeset(:update, user, params, extra))
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
    |> Changeset.cast_assoc(:character, with: &Characters.changeset/2)
    |> Changeset.cast_assoc(:profile, with: &Profiles.changeset/2)
    |> Changeset.cast_assoc(:accounted)
    |> Changeset.cast_assoc(:instance_admin)
    # |> Changeset.cast_assoc(:like_count)
    |> Changeset.cast_assoc(:encircles)
  end

  def changeset(:create, user, params, :remote) do
    User.changeset(user, params)
    |> override(:create, :remote)
    |> Changeset.cast_assoc(:character, with: &Characters.remote_changeset/2)
    |> Changeset.cast_assoc(:profile, with: &Profiles.changeset/2)
    # |> Changeset.cast_assoc(:like_count)
    |> Changeset.cast_assoc(:encircles)
    |> Changeset.cast_assoc(:peered)
  end


  def changeset(:update, user, params, _extra) do
    user = repo().preload(user, [:character, :profile])

    # add the ID for update
    params = params
      |> Map.merge(%{"profile" => %{"id"=> user.profile.id}}, fn _, a, b -> Map.merge(a, b) end)
      |> Map.merge(%{"character" => %{"id"=> user.character.id}}, fn _, a, b -> Map.merge(a, b) end)

    if params["profile"]["location"] && Utils.module_enabled?(Bonfire.Geolocate.Geolocations) do
      Bonfire.Geolocate.Geolocations.thing_add_location(user, user, params["profile"]["location"])
    end

    # Ecto doesn't liked mixed keys so we convert them all to strings
    params = for {k, v} <- params, do: {to_string(k), v}, into: %{}

    user
    |> User.changeset(params)
    |> Changeset.cast_assoc(:character, with: &Characters.changeset/2)
    |> Changeset.cast_assoc(:profile, with: &Profiles.changeset/2)
    |> Changeset.cast_assoc(:actor)
  end

   def admin_changeset(params),
    do: InstanceAdmin.changeset(%InstanceAdmin{}, params, [:id, :is_instance_admin])


end
