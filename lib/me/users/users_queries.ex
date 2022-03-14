defmodule Bonfire.Me.Users.Queries do

  import Ecto.Query
  import Bonfire.Me.Integration
  # alias Bonfire.Me.Users
  alias Bonfire.Data.Identity.User
  alias Bonfire.Common.Utils
  import EctoSparkles

  use Arrows

  def queries_module, do: User

  def query(filters, _opts \\ [])
  def query({:id, id}, _opts), do: by_id(id)
  def query({:username, username}, _opts), do: by_username_or_id(username)
  def query([filter], _opts), do: query(filter)

  defp query(), do: from(u in User, as: :user)

  def by_id(id) when is_binary(id), do: proloads(from(u in User, as: :user, where: u.id == ^id))

  def by_username_or_id(username_or_id) do # OR ID
    if Utils.is_ulid?(username_or_id),
      do: by_id(username_or_id),
      else: by_username_query(username_or_id)
  end

  def by_username_query(username) do
    from(u in User, as: :user)
    |> proloads()
    |> where([character: c], c.username == ^username)
  end

  defp proloads(query) do
    query
    |> proload(character: [:peered, :actor])
    |> proloads(:local)
  end

  defp proloads(query, :local) do
    proload query, [
      :accounted, :instance_admin,
      character: [:follow_count],
      profile: [:icon],
    ]
  end

  defp proloads(query, :minimal) do
    proload query, [:instance_admin, :character]
  end

  def by_account(account_id) do
    account_id = Utils.ulid(account_id)
    from(u in User, as: :user)
    |> proloads(:local)
    |> where([accounted: a], a.account_id == ^account_id)
  end

  def by_username_and_account(username, account_id) do
    if Utils.module_enabled?(Bonfire.Data.SharedUser) and Utils.module_enabled?(Bonfire.Me.SharedUsers) do
      Bonfire.Me.SharedUsers.by_username_and_account_query(username, account_id)
    else
      from(u in User, as: :user)
      |> proloads(:local)
      |> where([accounted: a], a.account_id == ^Utils.ulid(account_id))
      |> where([character: c], c.username == ^username)
    end
  end

  def current(user_id), do: by_id(user_id)

  def count(), do: repo().one(from p in User, select: count(p.id))

  def admins(proloads \\ :minimal) do
    from(u in User, as: :user)
    |> proloads(proloads)
    |> where([instance_admin: ia], ia.is_instance_admin == true)
  end

  def list() do
    from(u in User, as: :user,
      # join: a in assoc(u, :accounted),
      join: c in assoc(u, :character),
      join: p in assoc(u, :profile),
      left_join: ic in assoc(p, :icon),
      left_join: ia in assoc(u, :instance_admin),
      preload: [instance_admin: ia, character: c, profile: {p, [icon: ic]}]
    )
  end

  def search(text) do
    from(u in User, as: :user,
      # join: a in assoc(u, :accounted),
      join: c in assoc(u, :character),
      join: p in assoc(u, :profile),
      left_join: ic in assoc(p, :icon),
      left_join: ia in assoc(u, :instance_admin),
      preload: [instance_admin: ia, character: c, profile: {p, [icon: ic]}],
      where: ilike(p.name, ^"#{text}%")
      or ilike(p.name, ^"% #{text}%")
      or ilike(c.username, ^"#{text}%")
      or ilike(c.username, ^"% #{text}%")
    )
  end

end
