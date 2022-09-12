defmodule Bonfire.Me.SharedUsers do
  if Code.ensure_loaded?(Bonfire.Data.SharedUser) do
    alias Bonfire.Data.SharedUser
    alias Bonfire.Data.Identity.Account
    alias Bonfire.Data.Identity.User

    alias Bonfire.Me.Accounts
    alias Bonfire.Me.Users

    use Bonfire.Common.Utils
    import Bonfire.Common.Config, only: [repo: 0]
    alias Ecto.Changeset
    import Ecto.Query

    # temporary until these are implemented elsewhere
    def federation_module, do: ["Organization", "Service", "Application"]

    def add_accounts(
          shared_user_or_username,
          emails_or_usernames,
          params \\ %{}
        )

    def add_accounts(shared_user_or_username, emails_or_usernames, params)
        when is_binary(emails_or_usernames) do
      String.split(emails_or_usernames, ",")
      |> add_accounts(shared_user_or_username, ..., params)
    end

    def add_accounts(shared_user_or_username, emails_or_usernames, params)
        when is_list(emails_or_usernames) do
      shared_user_or_username =
        if is_struct(shared_user_or_username),
          do: repo().maybe_preload(shared_user_or_username, :shared_user),
          else: shared_user_or_username

      Enum.map(
        emails_or_usernames,
        &add_account(shared_user_or_username, &1, params)
      )
      # FIXME
      |> List.first()
    end

    def add_account(shared_user_or_username, email_or_username, params \\ %{})

    def add_account(username_to_share, email, params)
        when is_binary(username_to_share) do
      with {:ok, shared_user} <- Users.by_username(username_to_share) do
        repo().maybe_preload(shared_user, :shared_user)
        |> add_account(email, params)
      end
    end

    def add_account(%User{} = user_to_share, email_or_username, params)
        when is_binary(email_or_username) do
      # TODO: check that the authenticated account has permission to share this user

      case init_shared_user(user_to_share, params) do
        %SharedUser{} = shared_user ->
          email_or_username = String.trim(email_or_username)

          case Accounts.get_by_email(email_or_username) do
            %Account{} = account ->
              do_add_account(shared_user, account)

            _ ->
              case Users.by_username(email_or_username)
                   |> repo().maybe_preload(accounted: :account) do
                {:ok, %{accounted: %{account: %Account{} = account}}} ->
                  do_add_account(shared_user, account)

                _ ->
                  {:error,
                   l(
                     "Could not find an existing account on this instance with that email or username."
                   )}
              end
          end

        other ->
          {:error, "Could not turn this user identity into a shared user (got #{inspect(other)})"}
      end
    end

    defp do_add_account(
           %{shared_user: shared_user} = _user,
           %Account{} = account
         ) do
      do_add_account(shared_user, account)
    end

    # FIXME
    defp do_add_account(%SharedUser{} = shared_user, %Account{} = account) do
      # debug(account: account)
      repo().update(changeset(:add_account, shared_user, account))
    rescue
      e in Ecto.ConstraintError ->
        warn(e)
        :ok
    end

    def init_shared_user(%User{} = user, params \\ %{}) do
      user = repo().maybe_preload(user, :shared_user)
      shared_user = e(user, :shared_user, nil)

      if shared_user do
        shared_user
      else
        with {:ok, user} <-
               make_shared_user(user, params)
               |> repo().maybe_preload(:shared_user) do
          # add myself
          do_add_account(user, Utils.current_account(user))

          Map.get(user, :shared_user)
        end
      end
    end

    defp make_shared_user(%User{} = user, params),
      do: repo().update(changeset(:make_shared_user, user, params))

    defp changeset(:make_shared_user, %User{} = user, params) do
      params =
        params
        |> Utils.e("shared_user", params)
        # default label for shared users, do not localise here as it is a DB and schema level classification
        |> Map.put_new(
          "label",
          Bonfire.Common.Config.get_ext(
            :bonfire_me,
            :shared_user_default_label,
            "Team"
          )
        )

      user
      |> repo().preload(:shared_user)
      |> User.changeset(%{"shared_user" => params})
      |> Changeset.cast_assoc(:shared_user,
        with: &Bonfire.Data.SharedUser.changeset/2
      )
    end

    defp changeset(:add_account, shared_user, %Account{} = account) do
      shared_user
      # only update the user<>account association in question
      |> Map.put(:caretaker_accounts, [])
      # |> debug()
      |> SharedUser.changeset(%{})
      |> Changeset.put_assoc(:caretaker_accounts, [account])
    end

    def by_account(%Account{} = account) do
      # debug("shared by")
      account =
        repo().maybe_preload(
          account,
          [
            users: [:shared_user, :character, :profile],
            shared_users: [:shared_user, :character, :profile]
          ],
          false
        )

      Map.get(account, :users, []) ++ Map.get(account, :shared_users, [])
    end

    def by_account(account_id) when is_binary(account_id),
      do: by_account(Bonfire.Me.Accounts.fetch_current(account_id))

    def by_username_and_account_query(username, account) do
      from(u in User,
        join: p in assoc(u, :profile),
        left_join: ic in assoc(p, :icon),
        join: c in assoc(u, :character),
        join: a in assoc(u, :accounted),
        left_join: su in assoc(u, :shared_user),
        left_join: ca in assoc(u, :caretaker_accounts),
        where: c.username == ^username,
        where: a.account_id == ^ulid(account) or ca.id == ^ulid(account),
        preload: [profile: {p, [icon: ic]}, character: c, accounted: a],
        order_by: [asc: u.id]
      )
    end
  end
end
