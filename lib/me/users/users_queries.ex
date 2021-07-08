defmodule Bonfire.Me.Users.Queries do

  import Ecto.Query
  import Bonfire.Me.Integration

  # alias Bonfire.Me.Users
  alias Bonfire.Data.Identity.User
  alias Bonfire.Common.Utils

  # def queries_module, do: User

  def query(), do: from(u in User, as: :user)

  def by_id(id) do
    from u in User,
      join: p in assoc(u, :profile),
      join: c in assoc(u, :character),
      left_join: a in assoc(u, :actor),
      left_join: ac in assoc(u, :accounted),
      left_join: ia in assoc(u, :instance_admin),
      left_join: fc in assoc(c, :follow_count),
      left_join: ic in assoc(p, :icon),
      where: c.id == ^id,
      preload: [instance_admin: ia, profile: {p, [icon: ic]}, character: {c, [follow_count: fc]}, actor: a, accounted: ac]
  end

  def by_username_or_id(username_or_id) do # OR ID
    if Utils.is_ulid?(username_or_id) do
      by_id(username_or_id)
    else
      by_username_query(username_or_id)
    end
  end

  def by_username_query(username) do
    from u in User,
      join: p in assoc(u, :profile),
      join: c in assoc(u, :character),
      left_join: a in assoc(u, :actor),
      left_join: ac in assoc(u, :accounted),
      left_join: ia in assoc(u, :instance_admin),
      left_join: fc in assoc(c, :follow_count),
      left_join: ic in assoc(p, :icon),
      where: c.username == ^username,
      preload: [instance_admin: ia, profile: {p, [icon: ic]}, character: {c, [follow_count: fc]}, actor: a, accounted: ac]
  end

  def by_account(account_id) do
    from u in User,
      join: a in assoc(u, :accounted),
      join: c in assoc(u, :character),
      join: p in assoc(u, :profile),
      left_join: ia in assoc(u, :instance_admin),
      left_join: fc in assoc(c, :follow_count),
      where: a.account_id == ^account_id,
      preload: [instance_admin: ia, character: {c, [follow_count: fc]}, profile: p]
  end

  def by_username_and_account(username, account_id) do
    if Utils.module_enabled?(Bonfire.Data.SharedUser) do
      Bonfire.Me.SharedUsers.by_username_and_account_query(username, account_id)

    else
      from u in User,
        join: p in assoc(u, :profile),
        join: c in assoc(u, :character),
        join: a in assoc(u, :accounted),
        left_join: fc in assoc(c, :follow_count),
        left_join: ic in assoc(p, :icon),
        where: c.username == ^username,
        where: a.account_id == ^account_id,
        preload: [profile: {p, [icon: ic]}, character: {c, [follow_count: fc]}, accounted: a],
        order_by: [asc: u.id]
    end
  end

  def current(user_id) do
    from u in User,
      left_join: c in assoc(u, :character),
      join: ac in assoc(u, :accounted),
      join: a in assoc(ac, :account),
      left_join: p in assoc(u, :profile),
      left_join: i in assoc(c, :inbox),
      left_join: ia in assoc(u, :instance_admin),
      left_join: ic in assoc(p, :icon),
      where: u.id == ^user_id,
      preload: [instance_admin: ia, character: {c, inbox: i}, accounted: {ac, account: a}, profile: {p, [icon: ic]}]
  end

  def count() do
    repo().one(from p in User, select: count(p.id))
  end

  def admins() do
    from a in User,
      left_join: ia in assoc(a, :instance_admin),
      where: ia.is_instance_admin == true,
      preload: [instance_admin: ia]
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
