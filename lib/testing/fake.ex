defmodule Bonfire.Me.Fake do
  use Arrows
  import Untangle
  alias Bonfire.Data.Identity.Account
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Users

  # import Bonfire.Common.Simulation
  import Bonfire.Me.Fake.Helpers

  def fake_account!(attrs \\ %{}, opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:must_confirm?, false)
      |> Keyword.put_new(:skip_invite_check, true)

    {:ok, account} =
      signup_form(attrs)
      # |> debug
      |> Accounts.signup(..., opts)

    Map.put(account, :settings, nil)
  end

  # def fake_account!(attrs \\ %{}) do
  #   cs = Accounts.signup_changeset(Fake.account(attrs))
  #   assert {:ok, account} = repo().insert(cs)
  #   account
  # end

  def fake_user!(account \\ %{}, attrs \\ %{}, opts_or_extra \\ [])

  def fake_user!(%Account{} = account, attrs, opts_or_extra) do
    custom_username = attrs[:username]

    with cs <- Users.changeset(:create, create_user_form(attrs), account),
         {:ok, user} <- Users.create(cs, opts_or_extra) do
      Map.put(user, :settings, nil)
    else
      {:error, %Ecto.Changeset{} = e} when is_binary(custom_username) ->
        debug(e)
        Users.by_username!(custom_username)

      {:error, %Ecto.Changeset{valid?: false}} = e ->
        debug(e)
        i = opts_or_extra[:i] || 1
        if i < 3, do: fake_user!(account, attrs, opts_or_extra ++ [i: i + 1]), else: e
    end
  end

  def fake_user!(name, user_attrs, opts_or_extra) when is_binary(name) do
    fake_user!(
      fake_account!(),
      Enum.into(user_attrs, %{
        name: name,
        username: name
      }),
      opts_or_extra
    )
  end

  def fake_user!(account_attrs, user_attrs, opts_or_extra) do
    fake_account!(account_attrs)
    |> fake_user!(user_attrs, opts_or_extra)
  end
end
