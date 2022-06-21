defmodule Bonfire.Me.Accounts do

  use Arrows
  use Bonfire.Common.Utils
  import Bonfire.Me.Integration
  import Where

  alias Bonfire.Data.Identity.{Account, Credential, Email, User}
  alias Bonfire.Common.Config
  alias Bonfire.Me.Mails
  alias Bonfire.Me.Accounts.{
    ConfirmEmailFields,
    ForgotPasswordFields,
    ChangePasswordFields,
    LoginFields,
    Queries,
  }
  alias Bonfire.Me.Users
  alias Ecto.Changeset

  def get_current(nil), do: nil
  def get_current(id) when is_binary(id), do: repo().one(Queries.current(id)) #|> debug

  def fetch_current(nil), do: {:error, :not_found}
  def fetch_current(id) when is_binary(id), do: repo().single(Queries.current(id))

  def get_by_email(email) when is_binary(email), do: repo().one(Queries.by_email(email))

  @type changeset_name :: :change_password | :confirm_email | :login | :signup

  @spec changeset(changeset_name, params :: map) :: Changeset.t
  @spec changeset(changeset_name, params :: map, opts :: Keyword.t) :: Changeset.t
  def changeset(changeset_name, params, opts \\ [])

  def changeset(:forgot_password, params, _opts) when not is_struct(params),
    do: ForgotPasswordFields.changeset(params)

  def changeset(:change_password, params, opts) when not is_struct(params),
    do: ChangePasswordFields.changeset(%ChangePasswordFields{}, params, opts[:resetting_password])

  def changeset(:confirm_email, params, _opts) when not is_struct(params),
    do: ConfirmEmailFields.changeset(params)

  def changeset(:login, params, _opts) when not is_struct(params),
    do: LoginFields.changeset(params)

  def changeset(:signup, params, opts) do
    # debug(opts)
    if allow_signup?(opts) do
      signup_changeset(params, opts)
    else
      invite_error_changeset()
    end
  end

  defp signup_changeset(params, opts) do
    %Account{}
    |> Account.changeset(params)
    |> Changeset.cast_assoc(:email, required: true, with: &Email.changeset(&1, &2, opts))
    |> Changeset.cast_assoc(
      :credential,
      required: true,
      with: &Credential.confirmation_changeset(&1, &2)
    )
    |> Bonfire.Me.Accounts.SecondFactors.maybe_cast_totp_changeset(params, opts)
  end



  ### signup

  def signup(params_or_changeset, opts \\ [])

  def signup(params, opts) when not is_struct(params) do
    signup(changeset(:signup, params, opts), opts)
  end

  def signup(%Changeset{data: %Account{}}=cs, opts) do
    is_first_account = is_first_account?()

    opts = opts
    |> Keyword.put_new(
      :is_first_account,
      is_first_account
    )
    |> Keyword.put_new(
      :must_confirm?,
      Config.get(:env)==:test or !is_first_account && (!opts[:invite] || opts[:invite] != System.get_env("INVITE_KEY_EMAIL_CONFIRMATION_BYPASS"))
    )
    |> debug("opts")

    if cs.valid? do
      repo().transact_with fn -> # revert if email send fails
        repo().insert(cs)
        ~> maybe_redeem_invite(opts)
        ~> maybe_send_confirm_email(opts)
      end
    else
      {:error, cs} # avoid checking out txn
    end
  end

  ### login

  @doc """
  Attempts to log in by password and either username or email.

  Accepts a map of parameters or a `LoginFields` changeset.

  On success, returns `{:ok, account, user}` if a username was
  provided and `{:ok, account, nil}` otherwise.
  On error, returns `{:error, changeset}`
  """
  def login(params_or_changeset, opts \\ [])

  def login(params, opts) when not is_struct(params),
    do: login(changeset(:login, params, opts), opts ++ [params: params])

  def login(%Changeset{data: %LoginFields{}}=cs, opts) do
    with {:ok, form} <- Changeset.apply_action(cs, :insert) do
      repo().find(login_query(form), cs)
      ~> login_check_password(form, cs)
      ~> login_maybe_check_second_factor(cs, opts)
      ~> login_check_confirmed(cs, opts)
      ~> login_response()
    end
  end

  defp login_query(%{email: email}) when is_binary(email), do: Queries.login_by_email(email)

  defp login_query(%{username: username}) when is_binary(username), do: Queries.login_by_username(username)

  defp login_check_password(nil, _form, changeset) do
    Credential.dummy_check() # don't leak whether the user exists
    {:error, Changeset.add_error(changeset, :form, "no_match")}
  end

  defp login_check_password(%Account{}=account, form, changeset) do
    if Credential.check_password(form.password, e(account, :credential, :password_hash, nil)),
      do: {:ok, account},
      else: {:error, Changeset.add_error(changeset, :form, "no_match")}
  end

  defp login_maybe_check_second_factor(%Account{}=account, changeset, opts) do
    with {:ok, _} <- Bonfire.Me.Accounts.SecondFactors.maybe_authenticate(account, opts[:params]) do
      {:ok, account}
    else {:error, e} ->
      {:error, Changeset.add_error(changeset, :form, e)}
    end
  end

  defp login_check_confirmed(%Account{}=account, cs, opts) do
    if is_nil(e(account, :email, :confirmed_at, nil)) and Email.must_confirm?(opts),
      do: {:error, Changeset.add_error(cs, :form, "email_not_confirmed")},
      else: {:ok, account}
  end

  defp login_response(%Account{accounted: %{user: %User{}=user}}=account), do: {:ok, account, user}
  defp login_response(%Account{accounted: [%{user: %User{}=user}]}=account), do: {:ok, account, user}
  defp login_response(%Account{}=account) do
    # if there's only one user in the account, we can log them directly into it
    case Users.get_only_in_account(account) do
      {:ok, user} -> {:ok, account, user}
      :error ->
        {:ok, account, nil}
    end
  end

  ###  request_confirm_email

  def request_confirm_email(params_or_changeset_or_form_or_account, opts \\ [])

  def request_confirm_email(%Changeset{data: %ConfirmEmailFields{}}=cs, opts),
    do: Changeset.apply_action(cs, :insert) ~> rce_check_valid(cs, opts)

  def request_confirm_email(%Changeset{data: %ForgotPasswordFields{}}=cs, opts),
    do: Changeset.apply_action(cs, :insert) ~> rce_check_valid(cs, opts)

  def request_confirm_email(params, opts),
    do: request_confirm_email(changeset(:confirm_email, params, opts), opts)

  defp rce_check_valid(form, %Changeset{}=changeset, opts),
    do: rce_check_confirm(Email.must_confirm?(opts), form, changeset, opts)

  defp rce_check_confirm(false, _form, changeset, _opts),
    do: {:error, Changeset.add_error(changeset, :form, "confirmation_disabled")}

  defp rce_check_confirm(true, form, changeset, opts) do
    repo().one(Queries.request_confirm_email(form.email))
    |> rce_check_account(form, changeset, opts)
  end

  defp rce_check_account(nil, _form, changeset, _opts),
    do: {:error, Changeset.add_error(changeset, :form, "not_found")}

  defp rce_check_account(%Account{}=account, _form, changeset, opts),
    do: rce_check_what_to_do(account, changeset, opts)

  defp rce_check_what_to_do(account, changeset, opts) do

    what_to_do = if opts[:confirm_action] do
      Email.should_request_or_refresh?(account.email, opts)
    else
      Email.may_request_confirm_email?(account.email, opts)
    end

    case what_to_do do
      {:ok, :resend}  -> resend_confirm_email(account, opts)
      {:ok, :refresh} -> refresh_confirm_email(account, opts)
      {:error, error} -> {:error, Changeset.add_error(changeset, :form, error)}
    end
  end

  defp resend_confirm_email(%Account{}=account, opts) do
    with email_address when is_binary(email_address) <- e(account, :email, :email_address, nil),
    {:ok, _} <- mailer().send_now(Mails.confirm_email(account, opts), email_address),
      do: {:ok, :resent, account}
  end

  defp refresh_confirm_email(%Account{}=account, opts) do
    email = e(account, :email, nil)

    if email, do: repo().update(Email.put_token(email))       # put a new token
    ~> do_refresh_confirm_email(account, opts) # if that succeeds, send an email
  end

  defp do_refresh_confirm_email(email, account, opts) do
    account = %{ account | email: email }
    with {:ok, _} <- send_confirm_email(account, Keyword.put(opts, :must_confirm?, true)),
      do: {:ok, :refreshed, account}
  end


  ### confirm_email

  def confirm_email(account_or_token, opts \\ [])

  def confirm_email(%Account{}=account, _opts) do
    with {:ok, email} <- repo().update(Email.confirm(e(account, :email, nil))),
      do: {:ok, %{ account | email: email } }
  end

  def confirm_email(token, opts) when is_binary(token) do
    repo().transact_with fn ->
      repo().single(Queries.confirm_email(token))
      ~> ce(opts)
    end
  end

  defp ce(account, opts) do
    if opts[:confirm_action] do
      confirm_email(account)
    else
      with :ok <- Email.may_confirm?(account.email, opts),
        do: confirm_email(account)
    end
  end

  defp maybe_send_confirm_email(%Account{}=account, opts) do
    if Email.must_confirm?(opts) do
      send_confirm_email(account, opts)
    else
      debug("Skipping email confirmation")
      {:ok, account}
    end
  end

  defp send_confirm_email(account, opts) do
    case account do
      %{email: %{email_address: email}} ->
        mail = Mails.confirm_email(account, opts)
        mailer().send_now(mail, email)
        |> mailer_response(account)
      _ ->
        case repo().preload(account, :email) do
          %{email: %{email_address: email}} ->
            mail = Mails.confirm_email(account, opts)
            mailer().send_now(mail, email)
            |> mailer_response(account)
          _ -> {:error, :email_missing}
        end
    end
  end

  ### forgot/change password

  def request_forgot_password(params) do
    request_confirm_email(params, confirm_action: :forgot_password)
  end


  def change_password(current_account, params_or_changeset, opts \\ [])
  def change_password(current_account, params, opts) when not is_struct(params),
    do: change_password(current_account, changeset(:change_password, params, opts), params, opts)

  def change_password(%{id: _id} = current_account, %Changeset{}=cs, %{"old_password"=> old_password, "password"=> new_password} = _params, _opts) do
    current_account = current_account
    |> repo().preload(:credential)

    with {:ok, _} <- login_check_password(current_account, %{password: old_password}, cs) do
      change_password(current_account, cs, %{"password"=> new_password}, [resetting_password: true])
    end
  end

  def change_password(%{id: id} = current_account, %Changeset{}=cs, params, opts) do
    if cs.valid? and opts[:resetting_password] do
      current_account
      |> repo().preload(:credential)
      |> Account.changeset(%{credential: Map.merge(params, %{"id" => id})})
      |> Changeset.cast_assoc(:credential, required: true)
      |> repo().update()
    else
      {:error, cs} # avoid checking out tx
    end
  end

  ### invites

  def instance_is_invite_only? do
    Config.get(:env) != :test
    and
    Config.get(:invite_only)
    # System.get_env("INVITE_ONLY", "true") in ["true", true]
  end

  def allow_signup?(opts) do
    valid_invite = System.get_env("INVITE_KEY")
    special_invite = System.get_env("INVITE_KEY_EMAIL_CONFIRMATION_BYPASS")

    opts[:is_first_account]==true
    or !instance_is_invite_only?()
    or ( not is_nil(opts[:invite]) and opts[:invite] in [valid_invite, special_invite] )
    or redeemable_invite?(opts[:invite])
  end

  def redeemable_invite?(invite) do
    if module_enabled?(Bonfire.Invite.Links) and module_enabled?(Bonfire.InviteLink) and not is_nil(invite) do
      Bonfire.Invite.Links.redeemable?(invite)
    end
  end

  def maybe_redeem_invite(data, opts) do
    if module_enabled?(Bonfire.Invite.Links) and module_enabled?(Bonfire.InviteLink) do
      Bonfire.Invite.Links.redeem(opts[:invite])
    end
    data
  end

  defp invite_error_changeset do
    %Account{}
    |> Account.changeset(%{})
    |> Changeset.add_error(:form, "invite_only")
  end

  # defp delete_deps(account) do
  #   users = Users.by_account(account)
  #   Users.delete(users)
  # end

  ## misc

  defp mailer_response({:ok, _}, account), do: {:ok, account}
  defp mailer_response({:error, error}, _) when is_atom(error), do: {:error, error}
  defp mailer_response(_, _), do: {:error, :email}

  def is_first_account? do
    Queries.count() <1
  end

end
