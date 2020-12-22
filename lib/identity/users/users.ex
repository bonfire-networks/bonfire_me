defmodule Bonfire.Me.Identity.Users do
  @doc """
  A User is a logical identity within the system belonging to an Account.
  """
  use OK.Pipe
  alias Bonfire.Data.Identity.{Account, User}
  alias Bonfire.Me.Identity.Characters
  alias Bonfire.Me.Social.{Circles, Profiles}
  alias Pointers.Changesets
  alias Bonfire.Common.Utils
  alias Ecto.Changeset
  import Bonfire.Me.Integration
  import Ecto.Query

  @type changeset_name :: :create
  @type changeset_extra :: Account.t | :remote

  @spec create(params :: map, extra :: changeset_extra) :: Changeset.t

  def create(params, extra) do
    repo().insert(changeset(:create, %User{}, params, extra))
  end

  # def update(%User{} = user, params), do: repo().update(changeset(:update, user, params))

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
    |> Changeset.cast_assoc(:follow_count)
    |> Changeset.cast_assoc(:like_count)
    |> Changeset.cast_assoc(:encircles)
  end

  def changeset(:create, user, params, :remote) do
    User.changeset(user, params)
    |> override(:create, :remote)
    |> Changeset.cast_assoc(:character, with: &Characters.changeset/2)
    |> Changeset.cast_assoc(:profile, with: &Profiles.changeset/2)
    |> Changeset.cast_assoc(:follow_count)
    |> Changeset.cast_assoc(:like_count)
    |> Changeset.cast_assoc(:encircles)
  end

  # this is where we are very careful to explicitly set all the things
  # a user should have but shouldn't have control over the input for.
  defp override(changeset, changeset_type, extra \\ nil)

  defp override(changeset, :create, %Account{}=account) do
    Changeset.cast changeset, %{
      accounted:    %{account_id: account.id},
      follow_count: %{follower_count: 0, followed_count: 0},
      like_count:   %{liker_count: 0,    liked_count: 0},
      encircles:    [%{circle_id: Circles.circles().local}]
    }, []
  end

  defp override(changeset, :create, :remote) do
    Changeset.cast changeset, %{
      encircles: [%{circle_id: Circles.circles().activity_pub}]
    }, []
  end


  def by_account(%Account{id: id}), do: by_account(id)
  def by_account(account_id) when is_binary(account_id),
    do: repo().all(by_account_query(account_id))

  def by_account_query(account_id) do
    from u in User,
      join: a in assoc(u, :accounted),
      join: c in assoc(u, :character),
      join: p in assoc(u, :profile),
      where: a.account_id == ^account_id,
      preload: [character: c, profile: p]
  end

  def by_username(username), do: get_flat(by_username_query(username))

  def by_username_query(username) do
    from u in User,
      join: p in assoc(u, :profile),
      join: c in assoc(u, :character),
      left_join: a in assoc(u, :actor),
      join: ac in assoc(u, :accounted),
      where: c.username == ^username,
      preload: [profile: p, character: c, actor: a, accounted: ac]
  end

  def for_switch_user(username, account_id) do
    get_flat(for_switch_user_query(username))
    ~>> check_account_id(account_id)
  end

  def check_account_id(%User{}=user, account_id) do
    if user.accounted.account_id == account_id,
      do: {:ok, user},
      else: {:error, :not_permitted}
  end

  def for_switch_user_query(username) do
    from u in User,
      join: c in assoc(u, :character),
      join: a in assoc(u, :accounted),
      where: c.username == ^username,
      preload: [character: c, accounted: a],
      order_by: [asc: u.id]
  end

  def get_current(id), do: repo().one(get_current_query(id))

  def fetch_current(id), do: repo().single(get_current_query(id))

  defp get_current_query(id) do
    from u in User,
      join: c in assoc(u, :character),
      join: p in assoc(u, :profile),
      where: u.id == ^id,
      preload: [character: c, profile: p]
  end

  def flatten(user) do
    user
    |> Map.merge(user, user.profile)
    |> Map.merge(user, user.character)
  end

  def get_flat(query) do
    repo().single(query)
  end

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


end
