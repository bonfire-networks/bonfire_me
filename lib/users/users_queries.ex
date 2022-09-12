defmodule Bonfire.Me.Users.Queries do
  import Untangle
  import Ecto.Query
  import Bonfire.Me.Integration
  # alias Bonfire.Me.Users
  alias Bonfire.Data.Identity.User
  alias Bonfire.Common.Utils
  import Bonfire.Common.Extend
  import EctoSparkles

  use Arrows

  def queries_module, do: User

  def query(filters, _opts \\ [])
  def query({:id, id}, opts), do: by_id(id, opts)
  def query({:username, username}, opts), do: by_username_or_id(username, opts)
  def query([filter], opts), do: query(filter, opts)

  def query(filter, _opts) do
    error(filter, "No such filter defined")
    {:error, "Could not query"}
  end

  # defp query(), do: from(u in User, as: :user)

  def by_id(id, opts \\ []) when is_binary(id),
    do: from(u in User, as: :user, where: u.id == ^id) |> proloads(opts)

  # OR ID
  def by_username_or_id(username_or_id, opts \\ []) do
    if Utils.is_ulid?(username_or_id),
      do: by_id(username_or_id, opts),
      else: by_username_query(username_or_id)
  end

  def by_username_query(username, opts \\ []) do
    from(u in User, as: :user)
    |> proloads(opts)
    |> where([character: c], c.username == ^username)
  end

  defp proloads(query) do
    proloads(
      query,
      :default
    )
  end

  defp proloads(query, :local) do
    proload(query, [
      :accounted,
      :instance_admin,
      :settings,
      character: [:follow_count],
      profile: [:icon]
    ])
  end

  defp proloads(query, :admins) do
    proload(query, [
      :instance_admin
    ])
  end

  defp proloads(query, :minimal) do
    proload(query, [
      :instance_admin,
      character: [:peered],
      profile: [:icon]
    ])
  end

  defp proloads(query, opts) when is_list(opts) do
    proloads(query, Utils.e(opts, :preload, :minimal))
  end

  defp proloads(query, _default) do
    proload(query, [
      :instance_admin,
      profile: [:icon],
      character: [:peered]
    ])
  end

  def by_account(account_id) do
    account_id = Utils.ulid(account_id)

    from(u in User, as: :user)
    |> proloads(:local)
    |> where([accounted: a], a.account_id == ^account_id)
  end

  def by_username_and_account(username, account_id) do
    if module_enabled?(Bonfire.Data.SharedUser) do
      Bonfire.Me.SharedUsers.by_username_and_account_query(username, account_id)
    else
      from(u in User, as: :user)
      |> proloads(:local)
      |> where([accounted: a], a.account_id == ^Utils.ulid(account_id))
      |> where([character: c], c.username == ^username)
    end
  end

  def current(user_id), do: by_username_or_id(user_id, :local)

  def count(:local) do
    count(nil)
    |> join_peered()
    |> where([peered: p], is_nil(p.id))
  end

  def count(:remote) do
    count(nil)
    |> join_peered()
    |> where([peered: p], not is_nil(p.id))
  end

  def count(_) do
    select(User, [u], count(u.id))
  end

  def admins(opts \\ []) do
    from(u in User, as: :user)
    |> proloads(Utils.e(opts, :preload, :admins))
    |> where([instance_admin: ia], ia.is_instance_admin == true)
  end

  def list(:local) do
    list(nil)
    |> join_peered()
    |> where([peered: p], is_nil(p.id))
  end

  def list(:remote) do
    list(nil)
    |> join_peered()
    |> where([peered: p], not is_nil(p.id))
  end

  def list(_) do
    from(u in User,
      as: :user,
      # join: a in assoc(u, :accounted),
      join: c in assoc(u, :character),
      as: :character,
      join: p in assoc(u, :profile),
      left_join: ic in assoc(p, :icon),
      left_join: ia in assoc(u, :instance_admin),
      preload: [instance_admin: ia, character: c, profile: {p, [icon: ic]}]
    )
  end

  def join_peered(q) do
    q
    |> reusable_join(:left, [u], character in assoc(u, :character), as: :character)
    |> reusable_join(:left, [character: c], peered in assoc(c, :peered), as: :peered)
  end

  def search(text) do
    from(u in User,
      as: :user,
      # join: a in assoc(u, :accounted),
      join: c in assoc(u, :character),
      join: p in assoc(u, :profile),
      left_join: ic in assoc(p, :icon),
      left_join: ia in assoc(u, :instance_admin),
      preload: [instance_admin: ia, character: c, profile: {p, [icon: ic]}],
      where:
        ilike(p.name, ^"#{text}%") or
          ilike(p.name, ^"% #{text}%") or
          ilike(c.username, ^"#{text}%") or
          ilike(c.username, ^"% #{text}%")
    )
  end
end
