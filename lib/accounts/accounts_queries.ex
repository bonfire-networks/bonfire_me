defmodule Bonfire.Me.Accounts.Queries do
  @moduledoc "Queries for `Bonfire.Me.Accounts`"
  import Ecto.Query
  alias Bonfire.Data.Identity.Account
  # import Bonfire.Me.Integration
  import EctoSparkles

  @doc """
  Retrieves the current account by ID.

  ## Examples

      iex> Bonfire.Me.Accounts.Queries.current("some_id")
  """
  def current(id) when is_binary(id) do
    from(a in Account,
      where: a.id == ^id
    )
    |> proload([
      :settings,
      :instance_admin
    ])
  end

  @doc """
  Finds an account by email address.

  ## Examples

      iex> Bonfire.Me.Accounts.Queries.by_email("example@example.com")
      #Ecto.Query<...>
  """
  def by_email(email) when is_binary(email) do
    from(a in Account,
      join: e in assoc(a, :email),
      where: e.email_address == ^email,
      preload: [email: e]
    )
  end

  @doc """
  Finds an account by email confirmation token.

  ## Examples

      iex> by_confirm_token("some_token")
      #Ecto.Query<...>
  """
  def by_confirm_token(token) when is_binary(token) do
    from(a in Account,
      join: e in assoc(a, :email),
      where: e.confirm_token == ^token,
      preload: [email: e]
    )
  end

  @doc """
  Find an account by ID, preloading email and credential information.
  """
  def login_by_account_id(id) when is_binary(id) do
    from(a in Account,
      where: a.id == ^id
    )
    |> proload([
      # :instance_admin
      :email,
      :credential
    ])
  end

  @doc """
  Find an account by email address, preloading email and credential information.
  """
  def login_by_email(email) when is_binary(email) do
    from(a in Account,
      join: e in assoc(a, :email),
      join: c in assoc(a, :credential),
      where: e.email_address == ^email,
      preload: [email: e, credential: c]
    )
  end

  @doc """
  Find an account by username, preloading the user (with character, and profile information).
  """
  def login_by_username(username) when is_binary(username) do
    from(a in Account,
      join: c in assoc(a, :credential),
      join: e in assoc(a, :email),
      join: ac in assoc(a, :accounted),
      join: u in assoc(ac, :user),
      join: ch in assoc(u, :character),
      join: p in assoc(u, :profile),
      where: ch.username == ^username,
      preload: [
        email: e,
        credential: c,
        accounted: {ac, user: {u, character: ch, profile: p}}
      ]
    )
  end

  @doc """
  Counts the total number of accounts, or counts the number of records in the provided query.

  ## Examples

      iex> Bonfire.Me.Accounts.Queries.count()

      iex> Bonfire.Me.Accounts.Queries.count(from(a in Account, where: a.active == true))
  """
  def count(q \\ Account) do
    select(q, [u], count(u.id))
  end
end
