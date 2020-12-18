defmodule Bonfire.Me.Identity.Users.Queries do

  import Bonfire.Common.Config, only: [repo: 0]

  alias Bonfire.Me.Identity.Users
  import Ecto.Query

  def query(), do: from(u in User, as: :user)

  # def query

  defmacro filter(query, filters) when is_list(filters) do
    env = __CALLER__
    # Enum.reduce(filters, query, &macro_filter(&2, &1, env))
    nil
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
