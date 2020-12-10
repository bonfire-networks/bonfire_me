defmodule Bonfire.Me.Identity.Users do
  @doc """
  A User is a logical identity within the system belonging to an Account.
  """
  use OK.Pipe
  alias Bonfire.Data.Identity.{Account, User}
  alias Bonfire.Me.Identity.Users.CreateUserFields
  alias Pointers.Changesets
  alias Bonfire.Common.Utils
  alias Ecto.Changeset
  import Bonfire.Me.Integration
  import Ecto.Query

  def users() do
    [ guest: "N0TAVSER1FY0VTH1NKSAB0VT1T",
      local: "1AMASTAND1NF0RANY10CA1VSER",
    ]
  end

  def guest_user_id, do: "N0TAVSER1FY0VTH1NKSAB0VT1T"
  def local_user_id, do: "1AMASTAND1NF0RANY10CA1VSER"

  @type changeset_name :: :create

  @spec changeset(changeset_name, attrs :: map, %Account{}) :: Changeset.t
  def changeset(:create, attrs, %Account{}=account), do: CreateUserFields.changeset(attrs, account)

  def create(attrs, %Account{}=account) when not is_struct(attrs),
    do: create(changeset(:create, attrs, account))

  defp create(%Changeset{data: %CreateUserFields{}}=cs),
    do: Changeset.apply_action(cs, :insert) ~>> create()

  defp create(%CreateUserFields{}=form) do
    repo().put(create_changeset(Map.from_struct(form)))
  end

  def update(%User{} = user, attrs), do: repo().update(create_changeset(user, attrs))

  @counts %{
    follow_count:   0,
    follower_count: 0,
    like_count:     0,
    liker_count:    0,
  }

  def create_changeset(user \\ %User{}, attrs) do
    User.changeset(user, attrs)
    |> Changesets.cast_assoc(:accounted, attrs)
    |> Changesets.cast_assoc(:actor, attrs)
    |> Changesets.cast_assoc(:character, attrs)
    |> Changesets.cast_assoc(:follow_count, @counts)
    |> Changesets.cast_assoc(:like_count, @counts)
    |> Changesets.cast_assoc(:profile, attrs)
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
      join: a in assoc(u, :actor),
      join: ac in assoc(u, :accounted),
      where: c.username == ^username,
      preload: [profile: p, character: c, actor: a, accounted: ac]
  end

  def for_switch_user(username, account_id) do
    get_flat(for_switch_user_query(username))
    ~>> check_account_id(account_id)
    |> IO.inspect
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

  def get_current(username, %Account{id: account_id}),
    do: repo().single(get_current_query(username, account_id))

  defp get_current_query(username, account_id) do
    from u in User,
      join: c in assoc(u, :character),
      join: ac in assoc(u, :accounted),
      join: a in assoc(ac, :account),
      join: p in assoc(u, :profile),
      where: a.id == ^account_id,
      where: c.username == ^username,
      preload: [character: c, accounted: {ac, account: a}, profile: p]
  end

  def flatten(user) do
    user
    |> Map.merge(user, user.profile)
    |> Map.merge(user, user.character)
  end

  def get_flat(query) do
    repo().single(query)
  end

  def delete(%User{}=user) do
    preloads =
      [:actor, :character, :follow_count, :like_count, :profile, :self] ++
      [accounted: [:account]]
    user = Repo.preload(user, preloads)
    with :ok         <- delete_caretaken(user),
         {:ok, user} <- delete_mixins(user) do
      {:ok, user}
    end
  end

  # TODO: what must we chase down?
  # * acls
  # * accesses
  # * grants
  # * posts
  # * feeds
  defp delete_caretaken(user) do
    :ok
  end


  defp delete_mixins(user) do
    with {:ok, user} <- repo().delete(user.actor),
         {:ok, user} <- repo().delete(user.accounted),
         {:ok, user} <- repo().delete(user.character),
         {:ok, user} <- repo().delete(user.profile),
         {:ok, user} <- repo().delete(user.accounted),
         {:ok, user} <- repo().delete(user.accounted),
         {:ok, user} <- repo().delete(user.accounted) do
      {:ok, user}
    end
  end

end
