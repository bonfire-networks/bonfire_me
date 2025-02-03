defmodule Bonfire.Me.Accounts do
  @moduledoc """
  An account represents a private identity within the system, and can have many User identities (see `Bonfire.Me.Accounts`). An account usually has an `Bonfire.Data.Identity.Email` and a `Bonfire.Data.Identity.Credential` user for login.
  """

  use Arrows
  use Bonfire.Common.Utils
  import Bonfire.Me.Integration
  import Untangle

  alias Bonfire.Data.Identity.Account
  alias Bonfire.Data.Identity.Credential
  alias Bonfire.Data.Identity.Email
  alias Bonfire.Data.Identity.User

  alias Bonfire.Common.Config
  alias Bonfire.Me.Mails

  alias Bonfire.Me.Accounts.ConfirmEmailFields
  alias Bonfire.Me.Accounts.ForgotPasswordFields
  alias Bonfire.Me.Accounts.ChangePasswordFields
  alias Bonfire.Me.Accounts.ChangeEmailFields
  alias Bonfire.Me.Accounts.LoginFields
  alias Bonfire.Me.Accounts.Queries

  alias Bonfire.Me.Users
  alias Ecto.Changeset
  alias Needle.Changesets

  @doc """
  Returns the current account by its ID or nil if the ID is nil.

  ## Examples

      iex> get_current(nil)
      nil

      > get_current("some_id")
      %Account{id: "some_id"}

  """
  def get_current(nil), do: nil
  # |> debug
  def get_current(id) when is_binary(id), do: repo().maybe_one(Queries.current(id))

  @doc """
  Fetches the current account by its ID, returns `{:error, :not_found}` if the ID is nil.

  ## Examples

      iex> fetch_current(nil)
      {:error, :not_found}

      > fetch_current("some_id")
      {:ok, %Account{id: "some_id"}}

  """
  def fetch_current(nil), do: {:error, :not_found}

  def fetch_current(id) when is_binary(id),
    do: repo().single(Queries.current(id))

  @doc """
  Returns the account by its email.

  ## Examples

      > get_by_email("test@example.com")
      %Account{email: "test@example.com"}

  """
  def get_by_email(email) when is_binary(email),
    do: repo().one(Queries.by_email(email))

  @type changeset_name :: :change_password | :confirm_email | :login | :signup

  @doc """
  Returns a changeset for the given changeset name and parameters.

  ## Examples

      > changeset(:forgot_password, %{})
      %Changeset{}

      > changeset(:login, %{email: "test@example.com", password: "secret"})
      %Changeset{}

  """
  @spec changeset(changeset_name, params :: map) :: Changeset.t()
  @spec changeset(changeset_name, params :: map, opts :: Keyword.t()) ::
          Changeset.t()
  def changeset(changeset_name, params, opts \\ [])

  def changeset(:forgot_password, params, _opts) when not is_struct(params),
    do: ForgotPasswordFields.changeset(params)

  def changeset(:change_password, params, opts) when not is_struct(params),
    do:
      ChangePasswordFields.changeset(
        %ChangePasswordFields{},
        params,
        opts[:resetting_password]
      )

  def changeset(:change_email, params, _opts) when not is_struct(params),
    do:
      ChangeEmailFields.changeset(
        %ChangeEmailFields{},
        params
      )

  def changeset(:confirm_email, params, _opts) when not is_struct(params),
    do: ConfirmEmailFields.changeset(params)

  def changeset(:login, %{openid_email: _} = params, _opts) when not is_struct(params),
    do: struct(Ecto.Changeset, params)

  def changeset(:login, params, _opts) when not is_struct(params),
    do: LoginFields.changeset(params)

  def changeset(:signup, %{openid_email: email} = _params, opts) do
    if allow_signup?(opts) do
      signup_changeset_base(%{email: %{email_address: email}}, opts)
    else
      invite_error_changeset()
    end
  end

  def changeset(:signup, params, opts) do
    opts = prepare_signup_opts(opts)

    if allow_signup?(opts) do
      input_to_atoms(params)
      |> signup_changeset(opts)
    else
      invite_error_changeset()
    end
  end

  defp signup_changeset_base(params, opts) do
    %Account{}
    |> Account.changeset(params)
    |> Changeset.cast_assoc(:email,
      required: true,
      with: &Email.changeset(&1, &2, opts)
    )
  end

  defp signup_changeset(params, opts) do
    debug(opts)

    signup_changeset_base(params, opts)
    |> Changeset.cast_assoc(
      :credential,
      required: true,
      with: &Credential.confirmation_changeset(&1, &2)
    )
    |> Bonfire.Me.Accounts.SecondFactors.maybe_cast_totp_changeset(params, opts)
  end

  ### signup

  @doc """
  Signs up a new account with the given parameters.

  ## Examples

      > signup(%{email: "test@example.com", password: "secret"})
      {:ok, %Account{}}

      > signup(%Changeset{valid?: false})
      {:error, %Changeset{}}

  """
  def signup(params_or_changeset, opts \\ [])

  def signup(params, opts) when not is_struct(params) do
    signup(changeset(:signup, params, opts), opts ++ [params: params])
  end

  def signup(%Changeset{data: %Account{}} = cs, opts) do
    if cs.valid? do
      do_signup(cs, opts)
    else
      # avoid checking out txn
      {:error, cs}
    end
  end

  def signup(%Changeset{} = _cs, opts) do
    case opts[:params][:openid_email] do
      nil ->
        error("Did not find a valid signup changeset or OpenID email")

      email ->
        do_signup(%{email: email}, opts)
    end
  end

  def prepare_signup_opts(opts) do
    opts =
      opts
      |> Keyword.put_new_lazy(
        :is_first_account?,
        &is_first_account?/0
      )

    opts
    |> Keyword.put_new(
      :must_confirm?,
      !opts[:is_first_account?] or
        (opts[:invite] && opts[:invite] == System.get_env("INVITE_KEY_EMAIL_CONFIRMATION_BYPASS"))
      # Config.env() != :test
    )
  end

  def do_signup(%{} = cs_or_params, opts) do
    opts = prepare_signup_opts(opts)

    make_admin? = Config.env() != :test and opts[:is_first_account?]

    # revert if email send fails
    repo().transact_with(fn ->
      cs_or_params
      |> Changesets.put_assoc(:instance_admin, %{
        is_instance_admin: make_admin?
      })
      |> debug("changeset")
      |> repo().insert()
    end)
    ~> maybe_redeem_invite(opts)
    ~> maybe_send_confirm_email(opts)
  end

  ### login

  @doc """
  Attempts to log in by password and either username or email.

  Accepts a map of parameters or a `LoginFields` changeset.

  On success, returns `{:ok, account, user}` if a username was
  provided and `{:ok, account, nil}` otherwise.
  On error, returns `{:error, changeset}`

  ## Examples

      > login(%{email: "test@example.com", password: "secret"})
      {:ok, %Account{}, nil}

      > login(%{username: "test", password: "secret"})
      {:ok, %Account{}, %User{}}

      > login(%Changeset{valid?: false})
      {:error, %Changeset{}}

  """
  def login(params_or_changeset, opts \\ [])

  def login(params, opts) when not is_struct(params),
    do: login(changeset(:login, params, opts), opts ++ [params: params])

  def login(%Changeset{data: %LoginFields{}} = cs, opts) do
    with {:ok, form} <- Changeset.apply_action(cs, :insert) do
      repo().find(login_query(form), cs)
      ~> login_check_password(form, cs)
      ~> login_extras(cs, opts)
    end
  end

  def login(%Changeset{} = cs, opts) do
    debug(opts)

    case opts[:params][:openid_email] do
      nil ->
        error("Did not find a valid login changeset or OpenID email")

      email ->
        # TODO: should check that this user has previously authenticated with this provider

        Queries.by_email(email)
        |> repo().find(cs)
        # ~> login_check_password(form, cs) # skip for oauth
        ~> login_extras(cs, opts)
    end
  end

  defp login_extras(account, cs, opts) do
    account
    |> login_maybe_check_second_factor(cs, opts)
    ~> login_check_confirmed(cs, opts)
    ~> login_response()
  end

  def login_valid?(%{id: _user_id, accounted: %{account_id: account}} = _user, password) do
    login_valid?(account, password)
  end

  def login_valid?(account, password) do
    params = %{account_id: account, password: password}
    cs = changeset(:login, params, [])
    # ^ FIXME: should not need a changeset here
    with {:ok, _} <-
           repo().find(login_query(params), cs)
           ~> login_check_password(params, cs) do
      # ~> login_maybe_check_second_factor(cs, opts)
      # ~> login_check_confirmed(cs, opts) do
      true
    else
      e ->
        error(e)
        false
    end
  end

  defp login_query(%{email: email}) when is_binary(email),
    do: Queries.login_by_email(email)

  defp login_query(%{username: "@" <> username}),
    do: login_query(%{username: username})

  defp login_query(%{username: username}) when is_binary(username),
    do: Queries.login_by_username(username)

  defp login_query(%{account_id: account}) when is_binary(account),
    do: Queries.login_by_account_id(account)

  defp login_check_password(nil, _form, changeset) do
    # don't leak whether the user exists
    Credential.dummy_check()
    {:error, Changeset.add_error(changeset, :form, "no_match")}
  end

  defp login_check_password(%Account{} = account, form, changeset) do
    if Credential.check_password(
         form.password,
         e(account, :credential, :password_hash, nil)
       ),
       do: {:ok, account},
       else: {:error, Changeset.add_error(changeset, :form, "no_match")}
  end

  defp login_maybe_check_second_factor(%Account{} = account, changeset, opts) do
    with {:ok, _} <-
           Bonfire.Me.Accounts.SecondFactors.maybe_authenticate(
             account,
             opts[:params]
           ) do
      {:ok, account}
    else
      {:error, e} ->
        {:error, Changeset.add_error(changeset, :form, to_string(e))}
    end
  end

  defp login_check_confirmed(%Account{} = account, cs, opts) do
    if is_nil(e(account, :email, :confirmed_at, nil)) and
         Email.must_confirm?(opts),
       do: {:error, Changeset.add_error(cs, :form, "email_not_confirmed")},
       else: {:ok, account}
  end

  defp login_response(%Account{accounted: %{user: %User{} = user}} = account),
    do: validate_and_record_login_if_not_blocked(account, user)

  defp login_response(%Account{accounted: [%{user: %User{} = user}]} = account),
    do: validate_and_record_login_if_not_blocked(account, user)

  # defp login_response(%Account{accounted: users} = account) when is_list(users) and users != [] do
  #   # if none of the users are disabled we can show the user picker
  #   validate_and_record_login_if_not_blocked(account, users)
  # end

  defp login_response(%Account{} = account) do
    # if there's only one user in the account, we can log them directly into it
    case Users.get_only_in_account(account) do
      {:ok, user} ->
        validate_and_record_login_if_not_blocked(account, user)

      _ ->
        validate_and_record_login_if_not_blocked(account, nil)
    end
  end

  defp validate_and_record_login_if_not_blocked(account, user) do
    if user, do: Users.check_active!(user)

    # check if any other user on this account is blocked (TODO: optimise, eg by only fetching user ids)
    Users.by_account!(account)

    # OK now we now we can sign in, so we record the 'last seen' date/time
    maybe_apply(Bonfire.Social.Seen, :mark_seen, [user || account, account, [upsert: true]])
    |> debug("recorded last_login")

    {:ok, account, user}
  end

  ###  request_confirm_email

  @doc """
  Requests an email confirmation for the account.

  ## Examples

      > request_confirm_email(%{email: "test@example.com"})
      {:ok, :resent, %Account{}}

      > request_confirm_email(%Changeset{valid?: false})
      {:error, %Changeset{}}

  """
  def request_confirm_email(params_or_changeset_or_form_or_account, opts \\ [])

  def request_confirm_email(%Changeset{data: %ConfirmEmailFields{}} = cs, opts),
    do: Changeset.apply_action(cs, :insert) ~> rce_check_valid(cs, opts)

  def request_confirm_email(
        %Changeset{data: %ForgotPasswordFields{}} = cs,
        opts
      ),
      do: Changeset.apply_action(cs, :insert) ~> rce_check_valid(cs, opts)

  def request_confirm_email(params, opts),
    do: request_confirm_email(changeset(:confirm_email, params, opts), opts)

  defp rce_check_valid(form, %Changeset{} = changeset, opts),
    do: rce_check_confirm(Email.must_confirm?(opts), form, changeset, opts)

  defp rce_check_confirm(false, _form, changeset, _opts),
    do: {:error, Changeset.add_error(changeset, :form, "confirmation_disabled")}

  defp rce_check_confirm(true, form, changeset, opts) do
    repo().one(Queries.by_email(form.email))
    |> rce_check_account(form, changeset, opts)
  end

  defp rce_check_account(nil, _form, changeset, _opts),
    do: {:error, Changeset.add_error(changeset, :form, "not_found")}

  defp rce_check_account(%Account{} = account, _form, changeset, opts),
    do: rce_check_what_to_do(account, changeset, opts)

  defp rce_check_what_to_do(account, changeset, opts) do
    what_to_do =
      if opts[:confirm_action] do
        Email.should_request_or_refresh?(account.email, opts)
      else
        Email.may_request_confirm_email?(account.email, opts)
      end

    # |> debug()

    case what_to_do do
      {:ok, :resend} -> resend_confirm_email(account, opts)
      {:ok, :refresh} -> refresh_confirm_email(account, opts)
      # {:error, :already_confirmed} -> {:error, Changeset.add_error(changeset, :form, "Your email address was already confirmed. Please try to login instead.")}
      # {:error, :confirmation_disabled} -> {:error, Changeset.add_error(changeset, :form, "Email confirmation is disabled. Please try to login instead.")}
      # {:error, :no_expiry} -> {:error, Changeset.add_error(changeset, :form, "Email confirmation was invalid, please request a new one.")}
      {:error, error} -> {:error, Changeset.add_error(changeset, :form, to_string(error))}
    end
  end

  defp resend_confirm_email(%Account{} = account, opts) do
    with email_address when is_binary(email_address) <-
           e(account, :email, :email_address, nil),
         {:ok, _} <-
           mailer().send_now(Mails.confirm_email(account, opts), email_address),
         do: {:ok, :resent, account}
  end

  defp refresh_confirm_email(%Account{} = account, opts) do
    email = e(account, :email, nil)

    # put a new token
    if email,
      do:
        repo().update(Email.put_token(email))
        # if that succeeds, send an email
        ~> do_refresh_confirm_email(account, opts)
  end

  defp do_refresh_confirm_email(email, account, opts) do
    account = %{account | email: email}

    with {:ok, _} <-
           send_confirm_email(account, Keyword.put(opts, :must_confirm?, true)),
         do: {:ok, :refreshed, account}
  end

  ### confirm_email

  @doc """
  Confirms an account's email address as valid, usually by providing a confirmation token, or directly by providing an Account.

  ## Examples

      > confirm_email("some_token")
      {:ok, %Account{}}

      > confirm_email(%Account{})
      {:ok, %Account{}}

  """
  def confirm_email(account_or_token, opts \\ [])

  def confirm_email(%Account{} = account, _opts) do
    with {:ok, email} <- repo().update(Email.confirm(e(account, :email, nil))),
         do: {:ok, %{account | email: email}}
  end

  def confirm_email(token, opts) when is_binary(token) do
    repo().transact_with(fn ->
      repo().single(Queries.by_confirm_token(token))
      |> debug()
      ~> ce(opts)
      |> debug()
    end)
  end

  @doc """
  Confirms an account's email manually, by providing the email address. Only for internal or CLI use.

  ## Examples

      > confirm_email_manually("test@example.com")
      {:ok, %Account{}}

  """
  def confirm_email_manually(email) do
    with %Account{} = account <- get_by_email(email) do
      confirm_email(account)
    end
  end

  defp ce(%{email: %{id: _} = email} = account, opts) do
    if opts[:confirm_action] do
      confirm_email(account)
    else
      with :ok <- Email.may_confirm?(email, opts) |> debug(),
           do: confirm_email(account)
    end
  end

  defp ce(account, opts) do
    if opts[:confirm_action] do
      confirm_email(account)
    else
      error(account, "Could not find an email address to confirm")
    end
  end

  defp maybe_send_confirm_email(%Account{} = account, opts) do
    if Email.must_confirm?(opts) do
      send_confirm_email(account, opts)
    else
      debug("Skipping email confirmation")
      {:ok, account}
    end
  end

  defp send_confirm_email(account, opts) do
    mailer = mailer()
    mail = Mails.confirm_email(account, opts)

    if mailer do
      case account do
        %{email: %{email_address: email}} ->
          mailer().send_now(mail, email)
          |> mailer_response(account)

        _ ->
          case repo().preload(account, :email) do
            %{email: %{email_address: email}} ->
              mailer().send_now(mail, email)
              |> mailer_response(account)

            _ ->
              {:error, :email_missing}
          end
      end
    else
      error(
        mail,
        "No mailer module available. Missing configuration value: [:bonfire, :mailer_module]. Skipping sending of email confirmation"
      )

      {:ok, account}
    end
  end

  ### forgot/change password

  @doc """
  Requests a password reset to be sent for the account.

  ## Examples

      > request_forgot_password(%{email: "test@example.com"})
      {:ok, :resent, %Account{}}

  """
  def request_forgot_password(params) do
    request_confirm_email(params, confirm_action: :forgot_password)
  end

  @doc """
  Changes the password for the current account.

  ## Examples

      > change_password(%Account{}, %{old_password: "old", password: "new"})
      {:ok, %Account{}}

      > change_password(%Account{}, %Changeset{valid?: false})
      {:error, %Changeset{}}

  """
  def change_password(current_account, params_or_changeset, opts \\ [])

  def change_password(current_account, params, opts) when not is_struct(params),
    do:
      change_password(
        current_account,
        changeset(:change_password, params, opts),
        params,
        opts
      )

  def change_password(
        %{id: _id} = current_account,
        %Changeset{} = cs,
        %{"old_password" => old_password, "password" => new_password} = _params,
        _opts
      ) do
    current_account = repo().preload(current_account, :credential)

    with {:ok, _} <-
           login_check_password(current_account, %{password: old_password}, cs) do
      change_password(current_account, cs, %{"password" => new_password},
        resetting_password: true
      )
    end
  end

  def change_password(
        %{id: id} = current_account,
        %Changeset{} = cs,
        params,
        opts
      ) do
    if cs.valid? and opts[:resetting_password] do
      current_account
      |> repo().preload(:credential)
      |> Account.changeset(%{credential: Map.merge(params, %{"id" => id})})
      |> Changeset.cast_assoc(:credential, required: true)
      |> repo().update()
    else
      # avoid checking out tx
      {:error, cs}
    end
  end

  @doc """
  Changes the email for the current account.

  ## Examples

      > change_email(%Account{}, %{old_email: "old@example.com", email: "new@example.com"})
      {:ok, %Account{}}

      > change_email(%Account{}, %Changeset{valid?: false})
      {:error, %Changeset{}}

  """
  def change_email(current_account, params_or_changeset, opts \\ [])

  def change_email(current_account, params, opts) when not is_struct(params),
    do:
      maybe_change_email(
        current_account,
        changeset(:change_email, params, opts),
        params,
        opts
      )

  defp maybe_change_email(
         %{id: account_id} = current_account,
         %Changeset{} = cs,
         %{"old_email" => old, "email" => new} = _params,
         opts
       ) do
    with %Account{id: id} when id == account_id <- get_by_email(old) do
      do_change_email(current_account, cs, new, opts)
    else
      _ ->
        {:error, :not_found}
    end
  end

  defp do_change_email(
         %{id: id} = current_account,
         %Changeset{} = cs,
         new,
         opts
       ) do
    if cs.valid? do
      with {:ok, %{email: %{email_address: new_saved}} = account} when new == new_saved <-
             current_account
             |> repo().preload(:email)
             |> Account.changeset(%{email: Map.merge(%{"email_address" => new}, %{"id" => id})})
             |> Changeset.cast_assoc(:email, required: true)
             |> repo().update()
             ~> maybe_send_confirm_email(opts) do
        {:ok, account}
      end
    else
      # avoid checking out tx
      {:error, cs}
    end
  end

  ### invites

  @doc """
  Checks if the instance is invite-only.

  ## Examples

      > instance_is_invite_only?()
      true

  """
  def instance_is_invite_only? do
    (Config.env() != :test and
       Config.get(:invite_only)) || false

    # System.get_env("INVITE_ONLY", "true") in ["true", true]
  end

  @doc """
  Checks if signup is allowed based on instance config and provided options.

  ## Examples

      iex> allow_signup?(%{invite: "invite_code"})
      true

  """
  def allow_signup?(opts) do
    valid_invite = System.get_env("INVITE_KEY")
    special_invite = System.get_env("INVITE_KEY_EMAIL_CONFIRMATION_BYPASS")

    opts[:is_first_account?] == true or
      opts[:skip_invite_check] == true or !instance_is_invite_only?() or
      (not is_nil(opts[:invite]) and
         opts[:invite] in [valid_invite, special_invite]) or
      redeemable_invite?(opts[:invite])
  end

  def redeemable_invite?(invite) do
    module = maybe_module(Bonfire.Invite.Links)

    if not is_nil(module) && not is_nil(invite) do
      module.redeemable?(invite)
    end
  end

  def maybe_redeem_invite(data, opts) do
    module = maybe_module(Bonfire.Invite.Links, opts)

    if not is_nil(module) do
      module.redeem(opts[:invite])
    end

    data
  end

  defp invite_error_changeset do
    %Account{}
    |> Account.changeset(%{})
    |> Changeset.add_error(:form, "invite_only")
  end

  @doc """
  Enqueues the deletion of the given account.

  ## Examples

      > enqueue_delete(%Account{})
      :ok

      > enqueue_delete("some_account_id")
      :ok

  """
  def enqueue_delete(%{} = account) when is_struct(account) do
    account =
      account
      |> repo().maybe_preload(:users)

    Bonfire.Me.DeleteWorker.enqueue_delete([account] ++ e(account, :users, []))
  end

  def enqueue_delete(account) when is_binary(account) do
    account =
      get_current(account) ||
        Bonfire.Boundaries.load_pointer(account, include_deleted: true, skip_boundary_check: true)

    enqueue_delete(account)
  end

  @doc """
  Deletes the given account - use `enqueue_delete/1` instead.

  ## Examples

      iex> delete(%Account{})
      :ok

      iex> delete("some_account_id")
      :ok

  """
  def delete(account, _opts \\ [])

  def delete(%Account{} = account, _opts) do
    delete_users(account)

    assocs = [
      :credential,
      :email,
      :accounted,
      # :users, # handled by `delete_users/1`
      :shared_users,
      :auth_second_factor,
      :settings
    ]

    # account = repo().maybe_preload(account, assocs)
    Bonfire.Common.Utils.maybe_apply(
      Bonfire.Social.Objects,
      :maybe_generic_delete,
      [
        Account,
        account,
        [current_account: account, delete_associations: assocs, delete_caretaken: true]
      ]
    )

    # repo().delete(account) # handled by Epic
  end

  def delete(account, _opts) do
    with {:ok, account} <- fetch_current(account) do
      delete(account)
    else
      _ ->
        # re-delete already deleted pointable (eg. to catch any missing assocs)
        Bonfire.Common.Needles.get(account,
          deleted: true,
          skip_boundary_check: true
        )
        ~> delete()
    end
  end

  defp delete_users(account) do
    Users.by_account(account)
    |> Users.delete()
  end

  ## misc

  defp mailer_response({:ok, _}, account), do: {:ok, account}

  defp mailer_response({:error, :mailer_timeout}, account),
    #  we ignore mailer timeouts to avoid blocking the signup
    do: {:ok, account}

  defp mailer_response({:error, error}, _) when is_atom(error),
    do: {:error, error}

  defp mailer_response(_, _), do: {:error, :email}

  @doc """
  Counts the number of accounts.

  ## Examples

      iex> count()
      42

  """
  def count(), do: repo().one(Queries.count())

  def is_first_account? do
    count() < 1
  end

  def update_is_admin(user_or_account, make_admin_or_revoke, user \\ nil)

  def update_is_admin(%User{} = user, make_admin_or_revoke, _) do
    user
    |> repo().preload(:account)
    |> Map.get(:account)
    |> update_is_admin(make_admin_or_revoke, user)
  end

  def update_is_admin(%Account{} = account, true, user) do
    instance_admin = %{
      is_instance_admin: true,
      user: user
    }

    account
    |> repo().preload(instance_admin: [:user])
    |> debug()
    # |> Changeset.cast(
    #   %{instance_admin: instance_admin},
    #   []
    # )
    # |> Changeset.cast_assoc(:instance_admin)
    |> Changesets.put_assoc(:instance_admin, instance_admin)
    |> debug()
    |> repo().update()
  end

  def update_is_admin(%Account{} = account, _, _user) do
    # delete mixin
    account
    |> repo().preload([:instance_admin])
    |> Map.get(:instance_admin)
    |> repo().delete()
  end

  @doc """
  Checks if the given user or account is an admin.

  ## Examples

      > is_admin?(user)
      true

      > is_admin?(account)
      true

  """
  def is_admin?(%{instance_admin: %{is_instance_admin: val}}),
    do: val

  def is_admin?(%{current_account: %{instance_admin: %{is_instance_admin: val}}}),
    do: val

  def is_admin?(%{current_account: %{instance_admin: nil}}),
    do: false

  def is_admin?(%{current_user: %{instance_admin: %{is_instance_admin: val}}}),
    do: val

  def is_admin?(%{current_user: %{instance_admin: nil}}),
    do: false

  def is_admin?(%{account: %{instance_admin: %{is_instance_admin: val}}}),
    do: val

  def is_admin?(%{account: %{instance_admin: nil}}),
    do: false

  def is_admin?(%{instance_admin: nil}),
    do: false

  def is_admin?(assigns) when is_list(assigns) or is_map(assigns) do
    case current_user(assigns) do
      nil ->
        false

      current_user when current_user == assigns ->
        false

      current_user ->
        is_admin?(current_user)
    end ||
      case current_account(assigns) do
        nil ->
          false

        current_account when current_account == assigns ->
          warn(
            current_account,
            "You should make sure instance_admin assoc is loaded before using this function... returning false to avoid n+1 preloads and infinite loop"
          )

          false

        current_account ->
          is_admin?(current_account)
      end
  end

  def is_admin?(_), do: false

  def make_account(attrs \\ %{}, opts \\ []) do
    with {:ok, account} <- signup(attrs, opts) do
      {:ok, Map.put(account, :settings, nil)}
    end
  end
end
