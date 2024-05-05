defmodule Bonfire.Me do
  @moduledoc "./README.md" |> File.stream!() |> Enum.drop(1) |> Enum.join()

  import Untangle

  def make_account_and_user(name, email, password, opts \\ []) do
    with {:ok, account} <- make_account_only(email, password, opts),
         {:ok, user} <-
           Bonfire.Me.Users.make_user(
             %{profile: %{name: name}, character: %{username: name}},
             account,
             opts
           ) do
      IO.puts("User created!")
      {:ok, user}
    else
      e ->
        error(e, "Could not create user")
    end
  end

  def make_account_only(email, password, opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:must_confirm?, false)
      |> Keyword.put_new(:skip_invite_check, true)

    with {:ok, account} <-
           %{email: %{email_address: email}, credential: %{password: password}}
           |> Bonfire.Me.Accounts.make_account(opts) do
      IO.puts("Account created!")
      {:ok, account}
    else
      e ->
        error(e, "Could not create account")
    end
  end

  defdelegate make_admin(username), to: Bonfire.Me.Users
end
