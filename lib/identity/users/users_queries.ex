defmodule Bonfire.Me.Identity.Users.Queries do

  import Ecto.Query
  import Bonfire.Me.Integration

  # alias Bonfire.Me.Identity.Users
  alias Bonfire.Data.Identity.User

  def query(), do: from(u in User, as: :user)

  def with_mixins() do
    from(u in User, as: :user,
      # join: a in assoc(u, :accounted),
      join: c in assoc(u, :character),
      join: p in assoc(u, :profile),
      preload: [character: c, profile: p]
    )
  end

  def by_id(id) do
    from u in User,
      join: p in assoc(u, :profile),
      join: c in assoc(u, :character),
      where: u.id == ^id,
      preload: [profile: p, character: c]
  end


  # def query

  defmacro filter(query, filters) when is_list(filters) do
    env = __CALLER__
    # Enum.reduce(filters, query, &macro_filter(&2, &1, env))
    nil
  end

  def by_account(account_id) do
    from u in User,
      join: a in assoc(u, :accounted),
      join: c in assoc(u, :character),
      join: p in assoc(u, :profile),
      where: a.account_id == ^account_id,
      preload: [character: c, profile: p]
  end

  def by_username(username) do
    from u in User,
      join: p in assoc(u, :profile),
      join: c in assoc(u, :character),
      left_join: a in assoc(u, :actor),
      join: ac in assoc(u, :accounted),
      where: c.username == ^username,
      preload: [profile: p, character: c, actor: a, accounted: ac]
  end

  def for_switch_user(username, account_id) do
    from u in User,
      join: p in assoc(u, :profile),
      join: c in assoc(u, :character),
      join: a in assoc(u, :accounted),
      where: c.username == ^username,
      where: a.account_id == ^account_id,
      preload: [profile: p, character: c, accounted: a],
      order_by: [asc: u.id]
  end

  def current(user_id) do
    from u in User,
      join: c in assoc(u, :character),
      join: ac in assoc(u, :accounted),
      join: a in assoc(ac, :account),
      join: p in assoc(u, :profile),
      where: u.id == ^user_id,
      preload: [character: c, accounted: {ac, account: a}, profile: p]
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
