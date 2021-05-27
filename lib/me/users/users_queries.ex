defmodule Bonfire.Me.Users.Queries do

  import Ecto.Query
  import Bonfire.Me.Integration

  # alias Bonfire.Me.Users
  alias Bonfire.Data.Identity.User
  alias Bonfire.Common.Utils

  def query(), do: from(u in User, as: :user)

  def with_mixins() do
    from(u in User, as: :user,
      # join: a in assoc(u, :accounted),
      join: c in assoc(u, :character),
      join: p in assoc(u, :profile),
      left_join: ic in assoc(p, :icon),
      left_join: ia in assoc(u, :instance_admin),
      preload: [instance_admin: ia, character: c, profile: {p, [icon: ic]}]
    )
  end

  def by_id(id) do
    from u in User,
      join: p in assoc(u, :profile),
      join: c in assoc(u, :character),
      left_join: ia in assoc(u, :instance_admin),
      where: u.id == ^id,
      preload: [instance_admin: ia, profile: p, character: c]
  end


  # def query

  # defmacro filter(query, filters) when is_list(filters) do
  #   env = __CALLER__
  #   # Enum.reduce(filters, query, &macro_filter(&2, &1, env))
  #   nil
  # end

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

  def by_username(username_or_id) do # OR ID
    if Utils.is_ulid?(username_or_id) do
      by_id_query(username_or_id)
    else
      by_username_query(username_or_id)
    end
  end

  def by_id_query(username) do
    from u in User,
      join: p in assoc(u, :profile),
      join: c in assoc(u, :character),
      left_join: a in assoc(u, :actor),
      left_join: ac in assoc(u, :accounted),
      left_join: ia in assoc(u, :instance_admin),
      left_join: fc in assoc(c, :follow_count),
      left_join: ic in assoc(p, :icon),
      where: c.id == ^username,
      preload: [instance_admin: ia, profile: {p, [icon: ic]}, character: {c, [follow_count: fc]}, actor: a, accounted: ac]
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

  def for_switch_user(username, account_id) do
    if Utils.module_enabled?(Bonfire.Me.SharedUsers) do
      Bonfire.Me.SharedUsers.query_for_switch_user(username, account_id)

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


  # defp macro_filter(query, {join_: [{source, [{rel, as}]}]}, _env),
  #   do: join_as(query, source, :inner, rel, as)

  # defp macro_filter(query, {left_join_as: [{source, [{rel, as}]}]}, _env),
  #   do: join_as(query, source, :left, rel, as)

  # defp macro_filter(query, {:join_mixins, [{source, [mixins]}]}, _env) do

  # end

  # defp join_mixins(query, qual, source, mixins, env) do
  #   Enum.reduce(mixins, query, &join_mixin(&2, &1, qual, source, env))
  # end

  # defp join_mixin(query, {rel, as}, qual, source, env),
  #   do: join_as(env, query, source, qual, rel, as)

  # # defp join_mixin(query, rel, source, env),
  # #   do:

  # defp join_mixin(env, query, source, qual, rel),
  #   do: join_as(env, query, source, qual, rel, rel)

  # @doc false
  # def join_as_impl(query, source, qual, rel, as) do
  #   quote do
  #     Ecto.Query.join unquote(query), unquote(qual),
  #       x in assoc(as(unquote(source)), unquote(rel)),
  #       as: unquote(as)
  #   end
  # end

end
