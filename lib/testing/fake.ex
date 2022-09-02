defmodule Bonfire.Me.Fake do
  use Arrows
  # import Untangle
  alias Bonfire.Data.Identity.Account
  alias Bonfire.Me.{Accounts, Users}

  import Bonfire.Me.Fake.Helpers

  def fake_account!(attrs \\ %{}, opts \\ []) do
    opts = Keyword.put_new(opts, :must_confirm?, false)
    {:ok, account} = signup_form(attrs)
    # |> dump
    |> Accounts.signup(..., opts)

    account
    |> Map.put(:settings, nil)
  end

  # def fake_account!(attrs \\ %{}) do
  #   cs = Accounts.signup_changeset(Fake.account(attrs))
  #   assert {:ok, account} = repo().insert(cs)
  #   account
  # end

  def fake_user!(account \\ %{}, attrs \\ %{})

  def fake_user!(%Account{}=account, attrs) do
    custom_username = attrs[:character][:username]

    with {:ok, user} <- Users.create(create_user_form(attrs), account) do
      user
      |> Map.put(:settings, nil)
    else
      {:error, %Ecto.Changeset{}} when is_binary(custom_username) ->
        Users.by_username!(custom_username)
    end
  end

  def fake_user!(name, user_attrs) when is_binary(name) do
    fake_account!()
    |> fake_user!(Map.merge(user_attrs, %{profile: %{name: name}, character: %{username: name}}))
  end

  def fake_user!(account_attrs, user_attrs) do
    fake_account!(account_attrs)
    |> fake_user!(user_attrs)
  end

end
