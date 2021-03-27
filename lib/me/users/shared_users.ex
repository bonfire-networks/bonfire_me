if Code.ensure_loaded?(Bonfire.Data.SharedUser) do
defmodule Bonfire.Me.SharedUsers do
  alias Bonfire.Data.SharedUser

  alias Bonfire.Data.Identity.Account
  alias Bonfire.Data.Identity.User

  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Users

  alias Bonfire.Common.Utils
  import Bonfire.Common.Config, only: [repo: 0]
  alias Ecto.Changeset
  import Ecto.Query

  def add_account(username, email, params \\ %{}) when is_binary(username) do
    with {:ok, user} <- Users.by_username(username) do
      add_account(user, email, params)
    end
  end

  def add_account(%User{} = user, email, params) when is_binary(email) do
    # TODO: check that the authenticated account has permission to share this user

    shared_user = init_shared_user(user, params)

    #IO.inspect(made_shared_user: shared_user)

    if shared_user do

      account = Accounts.get_by_email(email)

      if account do

        #IO.inspect(account: account)

        repo().update(changeset(:add_account, shared_user, account))
      else
        {:error, "Could not find an account with that email."}
      end
    else
      {:error, "Could not share this user."}
    end
  end

  defp init_shared_user(%User{} = user, params) do

    user = repo().preload(user, :shared_user)
    share_user = Map.get(user, :shared_user)

    if share_user do
      share_user
    else
      with {:ok, user} <- make_shared_user(user, params) do

        user = repo().preload(user, :shared_user)

        Map.get(user, :shared_user)
      end
    end
  end

  def make_shared_user(%User{} = user, params), do: repo().update(changeset(:make_shared_user, user, params))

  defp changeset(:make_shared_user, %User{} = user, params) do

    params = Utils.put_new_in(params, ["shared_user", "label"], "Organisation") # default label for shared users

    user
    |> repo().preload(:shared_user)
    |> User.changeset(params)
    |> Changeset.cast_assoc(:shared_user)
  end

  defp changeset(:add_account, shared_user, %Account{}=account) do

    shared_user
    |> Map.put(:caretaker_accounts, []) # only update the user<>account association in question
    # |> IO.inspect()
    |> SharedUser.changeset(%{})
    |> Changeset.put_assoc(:caretaker_accounts, [account])
  end

  def by_account(%Account{} = account) do
    account = repo().preload(account, [users: [:shared_user, :character, :profile], shared_users: [:shared_user, :character, :profile]])
    (Map.get(account, :users, []) ++ Map.get(account, :shared_users, []))
    # |> IO.inspect
  end

  def by_account(account_id) when is_binary(account_id),
    do: by_account(Bonfire.Me.Accounts.fetch_current(account_id))


  def query_for_switch_user(username, account_id) do
      from u in User,
        join: p in assoc(u, :profile),
        join: c in assoc(u, :character),
        join: a in assoc(u, :accounted),
        left_join: su in assoc(u, :shared_user),
        left_join: ca in assoc(u, :caretaker_accounts),
        where: c.username == ^username,
        where: a.account_id == ^account_id or ca.id == ^account_id ,
        preload: [profile: p, character: c, accounted: a],
        order_by: [asc: u.id]
  end

end
end
