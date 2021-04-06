defmodule Bonfire.Me.Accounts.Queries do

  import Ecto.Query
  alias Bonfire.Data.Identity.Account

  def current(id) when is_binary(id) do
    from a in Account,
      where: a.id == ^id,
      left_join: i in assoc(a, :inbox),
      preload: [inbox: i]
  end

  def by_email(email) when is_binary(email) do
    from a in Account,
      join: e in assoc(a, :email),
      where: e.email_address == ^email,
      preload: [email: e]
  end

  def request_confirm_email(email) when is_binary(email) do
    from a in Account,
      join: e in assoc(a, :email),
      where: e.email_address == ^email,
      preload: [email: e]
  end

  def confirm_email(token) when is_binary(token) do
    from a in Account,
      join: e in assoc(a, :email),
      where: e.confirm_token == ^token,
      preload: [email: e]
  end

  def login_by_email(email) when is_binary(email) do
    from a in Account,
      join: e in assoc(a, :email),
      join: c in assoc(a, :credential),
      where: e.email_address == ^email,
      preload: [email: e, credential: c]
  end

  def login_by_username(username) when is_binary(username) do
    from a in Account,
      join: c in assoc(a, :credential),
      join: e in assoc(a, :email),
      join: ac in assoc(a, :accounted),
      join: u in assoc(ac, :user),
      join: ch in assoc(u, :character),
      join: p in assoc(u, :profile),
      where: ch.username == ^username,
      preload: [
        email: e, credential: c,
        accounted: {ac, user: {u, character: ch, profile: p}},
      ]
  end

end
