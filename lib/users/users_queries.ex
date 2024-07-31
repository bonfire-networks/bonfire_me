defmodule Bonfire.Me.Users.Queries do
  @moduledoc "Queries for `Bonfire.Me.Users`"

  import Untangle
  import Ecto.Query
  # alias Bonfire.Me.Integration
  # alias Bonfire.Me.Users
  alias Bonfire.Data.Identity.User
  alias Bonfire.Data.Identity.Account
  alias Bonfire.Data.Identity.Accounted
  use Bonfire.Common.Utils
  import Bonfire.Common.Extend
  import EctoSparkles

  use Arrows

  @behaviour Bonfire.Common.QueryModule
  def schema_module, do: User
  def context_module, do: Bonfire.Me.Users

  @doc """
  Queries for a user based on the given filter.

  ## Examples

      iex> Bonfire.Me.Users.Queries.query(id: "some_id")

      iex> Bonfire.Me.Users.Queries.query(username: "some_username")

      iex> Bonfire.Me.Users.Queries.query(:invalid_filter)
      {:error, "Could not query"}
  """
  def query(filters, _opts \\ [])
  def query({:id, id}, opts), do: by_id(id, opts)
  def query({:username, username}, opts), do: by_username_or_id(username, opts)
  def query([filter], opts), do: query(filter, opts)

  def query(filter, _opts) do
    error(filter, "No such filter defined")
    {:error, "Could not query"}
  end

  # defp query(), do: from(u in User, as: :user)

  def base_query do
    from(u in User,
      as: :user
      # join: a in assoc(u, :accounted),
      # join: c in assoc(u, :character), as: :character,
      # join: p in assoc(u, :profile), as: :profile,
      # left_join: ic in assoc(p, :icon),
      # left_join: ia in assoc(u, :instance_admin),
      # preload: [instance_admin: ia, character: c, profile: {p, [icon: ic]}]
    )
  end

  @doc """
  Searches for users based on a text string.

  ## Examples

      iex> Bonfire.Me.Users.Queries.search("userna")
  """
  def search(text, opts \\ []) when is_binary(text) do
    (opts[:query] || base_query())
    |> proload([
      # :instance_admin,
      :character,
      # : [:icon]
      :profile
    ])
    |> or_where(
      [profile: p, character: c],
      ilike(p.name, ^"#{text}%") or
        ilike(p.name, ^"% #{text}%") or
        ilike(p.summary, ^"#{text}%") or
        ilike(p.summary, ^"% #{text}%") or
        ilike(c.username, ^"#{text}%") or
        ilike(c.username, ^"% #{text}%")
    )
    |> prepend_order_by([profile: p, character: c], [
      {:desc,
       fragment(
         "(? <% ?)::int + (? <% ?)::int + (? <% ?)::int",
         ^text,
         c.username,
         ^text,
         p.name,
         ^text,
         p.summary
       )}
    ])
  end

  # def search(text) when is_binary(text) do
  #   from(u in User,
  #     as: :user,
  #     # join: a in assoc(u, :accounted),
  #     join: c in assoc(u, :character),
  #     join: p in assoc(u, :profile),
  #     left_join: ic in assoc(p, :icon),
  #     left_join: ia in assoc(u, :instance_admin),
  #     preload: [instance_admin: ia, character: c, profile: {p, [icon: ic]}],
  #     where:
  #       ilike(p.name, ^"#{text}%") or
  #         ilike(p.name, ^"% #{text}%") or
  #         ilike(c.username, ^"#{text}%") or
  #         ilike(c.username, ^"% #{text}%")
  #   )
  # end

  @doc """
  Returns for the current user based on the user ID.

  ## Examples

      iex> Bonfire.Me.Users.Queries.current("user_id")
  """
  def current(user_id), do: by_username_or_id(user_id, :current)

  @doc """
  Returns for the current user based on the user ID and account ID.

  ## Examples

      iex> Bonfire.Me.Users.Queries.current("user_id", "account_id")
  """
  def current(user_id, account_id) when is_binary(account_id) do
    base_by_id(user_id)
    # NOTE: this to avoid loading the wrong account in the case of SharedUser
    |> reusable_join(
      :left,
      [user],
      accounted in Accounted,
      as: :accounted,
      on:
        accounted.account_id == ^account_id and
          accounted.id == user.id
    )
    |> reusable_join(
      :left,
      [accounted: accounted],
      account in Account,
      as: :account,
      on: accounted.account_id == account.id
    )
    |> proloads(:current)
  end

  def current(user_id, _), do: current(user_id)

  def base_by_id(id) when is_binary(id), do: from(u in User, as: :user, where: u.id == ^id)

  @doc """
  Gets a user by ID.

  ## Examples

      iex> Bonfire.Me.Users.Queries.by_id("user_id")
  """
  def by_id(id, opts \\ []),
    do:
      base_by_id(id)
      |> proloads(opts)

  @doc """
  Finds a user by username or ID.

  ## Examples

      iex> Bonfire.Me.Users.Queries.by_username_or_id("username_or_id")
  """
  def by_username_or_id(username_or_id, opts \\ []) do
    if Types.is_ulid?(username_or_id),
      do: by_id(username_or_id, opts),
      else: by_username_query(username_or_id, opts)
  end

  @doc """
  Finds a user by username.

  ## Examples

      iex> Bonfire.Me.Users.Queries.by_username_query("username")
  """
  def by_username_query(username, opts \\ []) do
    from(u in User, as: :user)
    |> proloads(opts)
    |> where([character: c], c.username == ^username)
  end

  @doc """
  Finds a user by username or user ID and account ID.

  ## Examples

      iex> Bonfire.Me.Users.Queries.by_user_and_account("username_or_user_id", "account_id")
  """
  def by_user_and_account(username_or_user_id, account_id) do
    if user_id = Types.ulid(username_or_user_id) do
      # if module = maybe_module(Bonfire.Me.SharedUsers) do # TODO
      #   module.by_username_and_account_query(user_id, account_id)
      # else
      from(u in User, as: :user)
      |> proloads(:local)
      |> where([account: account], account.id == ^Types.ulid(account_id))
      |> where([character: c], c.id == ^user_id)

      # end
    else
      if module = maybe_module(Bonfire.Me.SharedUsers) do
        module.by_username_and_account_query(username_or_user_id, account_id)
      else
        from(u in User, as: :user)
        |> proloads(:local)
        |> where([account: account], account.id == ^Types.ulid(account_id))
        |> where([character: c], c.username == ^username_or_user_id)
      end
    end
  end

  @doc """
  Finds users by account ID.

  ## Examples

      iex> Bonfire.Me.Users.Queries.by_account("account_id")
  """
  def by_account(account_id) do
    account_id = Types.ulid(account_id)

    from(u in User, as: :user)
    |> proloads(:local)
    |> where([account: account], account.id == ^account_id)
  end

  @doc """
  Finds a user by canonical URI.

  ## Examples

      iex> Bonfire.Me.Users.Queries.by_canonical_uri("canonical_uri")
  """
  def by_canonical_uri(canonical_uri, opts \\ []) do
    from(u in User, as: :user)
    |> proloads(opts)
    |> where([peered: p], p.canonical_uri == ^canonical_uri)
  end

  defp proloads(query, :current) do
    proloads(query, :minimal)
    # NOTE: we load account and settings here so the LoadCurrentUser LivePlug can set the current_account without a separate query
    |> proload([:settings, :shared_user, account: {"account_", [:settings, :instance_admin]}])

    # |> proload(accounted: [account: [:settings]])
  end

  defp proloads(query, :local) do
    proloads(query, :locals)
    |> proload([
      :account
    ])
  end

  defp proloads(query, :locals) do
    proloads(query, :admins)
    |> proload([
      # :settings,
      # character: [:follow_count],
    ])
  end

  defp proloads(query, :admins) do
    proloads(query, :minimal)
    |> proload([
      :instance_admin
    ])
  end

  defp proloads(query, :default) do
    proloads(query, :minimal)
    |> proload(
      # :instance_admin,
      character: [:peered]
    )
  end

  defp proloads(query, :profile) do
    proloads(query, :default)
    |> proload([
      :instance_admin,
      profile: [:icon, :image]
    ])
  end

  defp proloads(query, :minimal) do
    proload(query, [
      :character,
      profile: [:icon]
    ])
  end

  defp proloads(query, opts) when is_list(opts) do
    proloads(query, Utils.e(opts, :preload, :default))
  end

  defp proloads(query, _default) do
    proload(query, [
      :instance_admin,
      profile: [:icon],
      character: [:peered]
    ])
  end

  @doc """
  Counts the number of users.

  ## Examples

      iex> Bonfire.Me.Users.Queries.count(:all)

      iex> Bonfire.Me.Users.Queries.count(:local)

      iex> Bonfire.Me.Users.Queries.count(:remote)
  """
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

  @doc """
  Returns the query to list admin users.
  """
  def admins(opts \\ []) do
    from(u in User, as: :user)
    |> proloads(Utils.e(opts, :preload, :admins))
    |> where([instance_admin: ia], ia.is_instance_admin == true)
  end

  @doc """
  Lists all users, or local or remote users, or users by instance ID.

  ## Examples

      iex> Bonfire.Me.Users.Queries.list(:all)

      iex> Bonfire.Me.Users.Queries.list(:local)

      iex> Bonfire.Me.Users.Queries.list(:remote)

      iex> Bonfire.Me.Users.Queries.list({:instance, "instance_id"})
  """
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

  def list({:instance, id}) do
    list(nil)
    |> join_peered()
    |> reusable_join(:left, [peered: p], peer in assoc(p, :peer), as: :peer)
    |> where([peer: p], p.id == ^id)
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
      #  TODO: in config
      where: u.id != ^Bonfire.Me.Users.remote_fetcher(),
      preload: [instance_admin: ia, character: c, profile: {p, [icon: ic]}]
    )
  end

  def join_peered(q) do
    q
    |> reusable_join(:left, [u], character in assoc(u, :character), as: :character)
    |> reusable_join(:left, [character: c], peered in assoc(c, :peered), as: :peered)
  end
end
