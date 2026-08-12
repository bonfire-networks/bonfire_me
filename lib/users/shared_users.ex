if Code.ensure_loaded?(Bonfire.Data.SharedUser) do
  defmodule Bonfire.Me.SharedUsers do
    @moduledoc "Enables multiple people to share one identity, by associating one User with many Accounts. Context for `Bonfire.Data.SharedUser`"
    alias Bonfire.Data.SharedUser
    alias Bonfire.Data.Identity.Account
    alias Bonfire.Data.Identity.User

    alias Bonfire.Me.Users

    use Bonfire.Common.Utils
    use Bonfire.Common.Config
    import Bonfire.Common.Config, only: [repo: 0]
    alias Ecto.Changeset
    import Ecto.Query

    # the co-manager join table; each link is one row: (shared_user_id, account_id, user_id)
    @caretaker_join "bonfire_data_shared_user_accounts"

    # temporary until these are implemented elsewhere
    @behaviour Bonfire.Federate.ActivityPub.FederationModules
    def federation_module, do: ["Organization", "Service", "Application"]

    @doc "Marks a user in-memory as NOT a shared user, by setting its `:shared_user` assoc to a loaded `nil`. Lets code that classifies a known-never-shared actor (e.g. the service/instance actor) skip a DB preload of the assoc."
    def mark_not_shared(%User{} = user), do: %{user | shared_user: nil}
    def mark_not_shared(other), do: other

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
      |> Enum.split_with(&match?({:ok, _}, &1))
      # all adds target the same shared user, so surface the first error if any, otherwise return that shared user
      |> case do
        {[_ | _] = oks, []} -> List.last(oks)
        {_, [error | _]} -> error
        {[], []} -> {:ok, shared_user_or_username}
      end
    end

    # `params` is the creation data for a not-yet-shared user (e.g. its `label`); `opts` carries behaviour options, notably the acting identity for the permission check (`current_account:` or `current_user:`).
    def add_account(shared_user_or_username, email_or_username, params \\ %{}, opts \\ [])

    def add_account(username_to_share, email_or_username, params, opts)
        when is_binary(username_to_share) do
      with {:ok, user} <- Users.by_username(username_to_share) do
        add_account(repo().maybe_preload(user, :shared_user), email_or_username, params, opts)
      end
    end

    def add_account(%User{} = user_to_share, username, params, opts)
        when is_binary(username) do
      # pass `opts` so `init_shared_user` can record the acting user as the creator/first co-manager
      case init_shared_user(user_to_share, params, opts) do
        %SharedUser{} = shared_user ->
          if authorized_to_manage?(user_to_share, Utils.current_account(opts)) do
            add_resolved_user(shared_user, username)
          else
            error(username, l("You are not authorized to manage this shared user."))
          end

        other ->
          error(other, "Could not turn this user identity into a shared user")
      end
    end

    # Co-managers are invited by username, which identifies exactly one user. An email identifies an account that can own several users, so inviting by email would leak (and grant a display identity to) the account's other personas; hence username only.
    defp add_resolved_user(shared_user, username) do
      case username |> String.trim() |> String.trim("@") do
        "" ->
          info("No user to add was specified")
          {:ok, shared_user}

        username ->
          case Users.local_by_id_or_username(username) do
            %User{} = user ->
              do_add_account(shared_user, user)

            _ ->
              error(
                username,
                l("Could not find a user with that username on this instance.")
              )
          end
      end
    end

    @doc "Removes a co-manager identified by their user id or username; unlinks their whole account. The human-facing/GraphQL entry point; the roster's Remove button uses `remove_account/3` directly (it already holds the account id, so no lookup)."
    def remove_user(shared_user_or_username, user_id_or_username, opts \\ [])

    def remove_user(username_to_share, user_id_or_username, opts)
        when is_binary(username_to_share) do
      with {:ok, user} <- Users.by_username(username_to_share) do
        remove_user(user, user_id_or_username, opts)
      end
    end

    def remove_user(%User{} = shared, user_id_or_username, opts)
        when is_binary(user_id_or_username) do
      with %User{} = to_remove <-
             Bonfire.Me.Accounts.preload_account(
               Users.local_by_id_or_username(user_id_or_username)
             ) ||
               :not_found,
           account_id when is_binary(account_id) <-
             e(to_remove, :accounted, :account, :id, nil) || :not_found do
        remove_account(shared, account_id, opts)
      else
        _ -> error(user_id_or_username, l("Could not find that team member to remove."))
      end
    end

    @doc "Removes a co-manager by their account id (unlinks the whole account). `opts[:current_account]`/`opts[:current_user]` is the acting identity, whose account must itself be linked."
    def remove_account(%User{} = shared, account_id, opts \\ []) when is_binary(account_id) do
      # force-reload in case the passed struct predates this user becoming shared
      shared = repo().maybe_preload(shared, :shared_user, force: true)

      with %SharedUser{} = shared_user <- e(shared, :shared_user, nil) || :not_shared,
           true <- authorized_to_manage?(shared, Utils.current_account(opts)) || :unauthorized,
           # a shared user must always keep at least one account managing it
           true <- length(list_accounts(shared)) > 1 || :last_one do
        do_remove_account(shared_user, account_id)
      else
        :not_shared ->
          error(account_id, l("This is not a shared user."))

        :unauthorized ->
          error(account_id, l("You are not authorized to manage this shared user."))

        :last_one ->
          error(account_id, l("You can't remove the only team member managing this profile."))

        _ ->
          error(account_id, l("Could not remove that team member."))
      end
    end

    @doc "Lists the accounts currently linked to (co-managing) a shared user. Account-level: used for the permission check, not for display."
    def list_accounts(%User{} = user) do
      repo().maybe_preload(user, :caretaker_accounts)
      |> e(:caretaker_accounts, [])
    end

    def list_accounts(_), do: []

    @doc "Lists the specific users co-managing a shared user (the roster's display identities: the invited users and the creator). Excludes each account's other personas, so nothing leaks. Preloads `:accounted` so the roster can offer account-level removal without a lookup."
    def list_linked_users(%User{} = user) do
      repo().maybe_preload(user, caretaker_users: [:character, :profile, :accounted])
      |> e(:caretaker_users, [])
    end

    def list_linked_users(_), do: []

    @doc "Whether the given account co-manages the shared user via an account-only link (no specific user recorded), so it isn't among `list_linked_users`. One cheap existence check; the UI uses it to show a \"You\" row for the current account."
    def account_linked?(%User{} = user, account) do
      with shared_user_id when is_binary(shared_user_id) <- uid(user),
           account_id when is_binary(account_id) <- uid(account) do
        from(j in @caretaker_join,
          where:
            j.shared_user_id == type(^shared_user_id, Needle.ULID) and
              j.account_id == type(^account_id, Needle.ULID)
        )
        |> repo().exists?()
      else
        _ -> false
      end
    end

    # Any account already linked to the shared user may manage it. A nil acting account (a trusted/internal caller that didn't pass `current_account:`) is allowed, so existing callers keep working.
    defp authorized_to_manage?(_user, nil), do: true

    defp authorized_to_manage?(user, %Account{} = acting) do
      Enum.any?(list_accounts(user), &(&1.id == acting.id))
    end

    defp authorized_to_manage?(_user, _), do: false

    # The link is a single row in the join table, so add/remove it directly rather than syncing the whole many-to-many set (no full-set preload, no `on_replace`). `on_conflict: :nothing` (backed by the unique index) makes add idempotent.
    defp do_add_account(%{shared_user: %SharedUser{} = shared_user} = _user, addable),
      do: do_add_account(shared_user, addable)

    # an invited (or creating) user: record both its account (for account-level access) and the user itself (the display identity)
    defp do_add_account(%SharedUser{} = shared_user, %User{} = user) do
      user = Bonfire.Me.Accounts.preload_account(user)

      case e(user, :accounted, :account, nil) do
        %Account{} = account -> insert_caretaker(shared_user, account, user.id)
        _ -> error(user, l("That user has no account on this instance."))
      end
    end

    # a link with no specific user (fallback when the acting/creating user is unknown)
    defp do_add_account(%SharedUser{} = shared_user, %Account{} = account),
      do: insert_caretaker(shared_user, account, nil)

    defp insert_caretaker(%SharedUser{} = shared_user, %Account{} = account, user_id) do
      # the join table is schemaless here, so dump the ULIDs to the binary the pointer columns store. `on_conflict: :nothing` (backed by the unique index on shared_user_id+account_id) keeps add idempotent and one row per account.
      row =
        %{shared_user_id: dump_uid(shared_user.id), account_id: dump_uid(account.id)}
        |> maybe_put_uid(:user_id, user_id)

      repo().insert_all(@caretaker_join, [row], on_conflict: :nothing)

      {:ok, shared_user}
    end

    defp maybe_put_uid(row, _key, nil), do: row
    defp maybe_put_uid(row, key, id), do: Map.put(row, key, dump_uid(id))

    # removal is account-level: delete the single join row for this shared user + account id
    defp do_remove_account(%SharedUser{} = shared_user, account_id) when is_binary(account_id) do
      repo().delete_all(
        from(j in @caretaker_join,
          where:
            j.shared_user_id == type(^shared_user.id, Needle.ULID) and
              j.account_id == type(^account_id, Needle.ULID)
        )
      )

      {:ok, shared_user}
    end

    defp dump_uid(id) do
      {:ok, bin} = Needle.ULID.dump(Needle.ULID.cast!(id))
      bin
    end

    # `opts` carries the acting identity (`current_user:`/`current_account:`) so we can record the creator as the first co-manager.
    def init_shared_user(%User{} = user, params \\ %{}, opts \\ []) do
      # force-reload so a stale struct (e.g. loaded before this user became shared) doesn't make us re-create the mixin and hit a duplicate-pkey error
      user = repo().maybe_preload(user, :shared_user, force: true)

      if shared_user = e(user, :shared_user, nil) do
        # TODO: update label if a different one was supplied
        shared_user
      else
        with {:ok, user} <-
               make_shared_user(user, params)
               # also load `accounted: :account` so we can resolve the creating account as a fallback (a freshly-created user handed in from the create-user controller carries no session account otherwise)
               |> repo().maybe_preload([:shared_user, accounted: :account]) do
          # record the creator as the first co-manager: prefer the persona explicitly chosen at creation (`:shared_user_creator`), then the acting user, so the roster shows a real person; fall back to just the creating account when no user is known
          case opts[:shared_user_creator] || Utils.current_user(opts) do
            %User{} = creator -> do_add_account(user, creator)
            _ -> do_add_account(user, Utils.current_account(opts) || Utils.current_account(user))
          end

          Map.get(user, :shared_user)
        end
      end
    end

    defp make_shared_user(%User{} = user, params),
      do: repo().update(changeset(:make_shared_user, user, params))

    defp changeset(:make_shared_user, %User{} = user, params) do
      params =
        params
        |> e("shared_user", params)
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

    defp user_preloads do
      [:shared_user, :character, profile: [:icon]]
    end

    defp user_preload_query(opts) do
      from(u in User)
      |> Bonfire.Me.Users.Queries.maybe_exclude_user_id(opts)
      |> Bonfire.Me.Users.Queries.user_proloads(opts[:preload_type] || :minimal)
    end

    # WIP: testing a theory for the switch-user crash, where prod hit `ERROR 53100 (disk_full) could not resize shared memory segment`.
    # Postgres allocates that segment in `/dev/shm` (64MB by default under Docker) for a PARALLEL query, and Ecto issues the two preloads below CONCURRENTLY, so there are two possible ways to stop needing it. 
    # `PG_NO_PARALLEL_ACCOUNT_USERS` in env picks which to apply:
    #   1 = issue the two preloads serially (one query at a time, each still free to go parallel)
    #   2 = force a serial PLAN, so no query allocates a segment at all
    #   3 (or true/yes) = both
    defp no_parallel_account_users do
      case System.get_env("PG_NO_PARALLEL_ACCOUNT_USERS") do
        "1" -> {_serial_preloads? = true, _serial_plan? = false}
        "2" -> {false, true}
        both when both in ["3", "true", "yes"] -> {true, true}
        _ -> {false, false}
      end
    end

    defp preload_account_users(account, preload_spec) do
      {serial_preloads?, serial_plan?} = no_parallel_account_users()

      opts =
        [follow_pointers: false] ++
          if serial_preloads?, do: [in_parallel: false], else: []

      if serial_plan? do
        repo().transaction(fn ->
          repo().query!("SET LOCAL max_parallel_workers_per_gather = 0")
          repo().maybe_preload(account, preload_spec, opts)
        end)
        |> case do
          {:ok, preloaded} -> preloaded
          other -> error(other, "could not preload the account's users") && account
        end
      else
        repo().maybe_preload(account, preload_spec, opts)
      end
    end

    def by_account(%Account{} = account, opts \\ []) do
      preload_spec =
        [
          users: user_preload_query(opts),
          shared_users: user_preload_query(opts)
        ]
        |> debug("preload_spec")

      account =
        preload_account_users(account, preload_spec)
        |> debug("preloaded")

      # FIXME: should this call Accounts.by_account instead?

      Enum.uniq_by(
        e(account, :users, []) ++ e(account, :shared_users, []),
        &id/1
      )
    end

    def by_account(account_id, opts),
      do: Bonfire.Me.Accounts.fetch_current(account_id) ~> by_account(opts)

    def by_username_and_account_query(username, account) do
      from(u in User,
        join: p in assoc(u, :profile),
        left_join: ic in assoc(p, :icon),
        join: c in assoc(u, :character),
        join: a in assoc(u, :accounted),
        left_join: su in assoc(u, :shared_user),
        left_join: ca in assoc(u, :caretaker_accounts),
        where: c.username == ^username,
        where: a.account_id == ^uid(account) or ca.id == ^uid(account),
        preload: [profile: {p, [icon: ic]}, character: c, accounted: a],
        order_by: [asc: u.id]
      )
    end
  end
end
