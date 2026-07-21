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
  # Emails are matched case-insensitively (case-variant lookups used to silently miss — or split — accounts). Storage is untouched and may still hold rows differing only in case, so `matching_account_id/1` picks exactly one (preferring an exact match) in a subquery — the pick must NOT be a `limit` on this query itself, whose join-preloads would then be truncated to a single row.
  def by_email(email) when is_binary(email) do
    from(a in Account,
      join: e in assoc(a, :email),
      where: a.id == subquery(matching_account_id(email)),
      preload: [email: e]
    )
    |> proload(accounted: [user: :profile])
  end

  # The email mixin's id IS the account id (Needle mixin), so this selects the account.
  defp matching_account_id(email) do
    from(e in Bonfire.Data.Identity.Email,
      where: fragment("lower(?)", e.email_address) == ^String.downcase(email),
      order_by: [desc: fragment("? = ?", e.email_address, ^email)],
      limit: 1,
      select: e.id
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
  # Case-insensitive with exact-match preference, like `by_email/1`.
  def login_by_email(email) when is_binary(email) do
    from(a in Account,
      join: e in assoc(a, :email),
      left_join: c in assoc(a, :credential),
      where: a.id == subquery(matching_account_id(email)),
      preload: [email: e, credential: c]
    )
  end

  @doc """
  Find an account by username, preloading the user (with character, and profile information).
  """
  def login_by_username(username) when is_binary(username) do
    from(a in Account,
      left_join: c in assoc(a, :credential),
      left_join: e in assoc(a, :email),
      join: ac in assoc(a, :accounted),
      join: u in assoc(ac, :user),
      join: ch in assoc(u, :character),
      left_join: p in assoc(u, :profile),
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

  @doc """
  Lists all accounts with their email addresses and associated user details.
  Useful for admin purposes to see all registered emails and usernames.
  Only includes accounts that have an email address.
  Returns only the first created user per account (based on user ID/ULID).

  ## Examples

      iex> Bonfire.Me.Accounts.Queries.list_with_emails()
      #Ecto.Query<...>
  """
  def list_with_emails do
    from(a in Account,
      join: e in assoc(a, :email),
      left_join: ac in assoc(a, :accounted),
      left_join: u in assoc(ac, :user),
      left_join: c in assoc(u, :character),
      left_join: p in assoc(u, :profile),
      where: not is_nil(e.email_address) and e.email_address != "",
      distinct: a.id,
      order_by: [asc: a.id, asc: u.id],
      select: %{
        account_id: a.id,
        email: e.email_address,
        email_confirmed_at: e.confirmed_at,
        username: c.username,
        name: p.name,
        summary: p.summary
      }
    )
  end
end
