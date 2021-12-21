defmodule Bonfire.Me.Accounts do

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
  import Bonfire.Me.Integration
  use OK.Pipe

  def get_current(nil), do: nil
  def get_current(id) when is_binary(id),
    do: repo().one(Queries.current(id))

  def fetch_current(id) when is_binary(id),
    do: repo().single(Queries.current(id))

  def get_by_email(email) when is_binary(email),
    do: repo().one(Queries.by_email(email))

  @type changeset_name :: :change_password | :confirm_email | :login | :signup

  @spec changeset(changeset_name, params :: map) :: Changeset.t
  @spec changeset(changeset_name, params :: map, opts :: Keyword.t) :: Changeset.t
  def changeset(changeset_name, params, opts \\ [])

  def changeset(:forgot_password, params, _opts) when not is_struct(params),
    do: ForgotPasswordFields.changeset(params)

  def changeset(:change_password, params, _opts) when not is_struct(params),
    do: ChangePasswordFields.changeset(params)

  def changeset(:confirm_email, params, _opts) when not is_struct(params),
    do: ConfirmEmailFields.changeset(params)

  def changeset(:login, params, _opts) when not is_struct(params),
    do: LoginFields.changeset(params)

  def changeset(:signup, params, opts) do
    if not instance_is_invite_only? || opts[:invite] == System.get_env("INVITE_KEY") || is_first_account? do
      signup_changeset(params, opts)
    else
      invite_only_changeset()
    end
  end

  defp signup_changeset(params, opts) do
    %Account{}
      |> Account.changeset(params)
      |> Changeset.cast_assoc(:email, required: true, with: &Email.changeset(&1, &2, opts))
      |> Changeset.cast_assoc(:credential, required: true)
  end

  defp invite_only_changeset do
    %Account{}
      |> Account.changeset(%{})
      |> Changeset.add_error(:form, "invite_only")
  end

  ### signup

  def signup(params_or_changeset, opts \\ [])

  def signup(params, opts) when not is_struct(params),
    do: signup(changeset(:signup, params, opts), opts)

  def signup(%Changeset{data: %Account{}}=cs, opts) do
    if cs.valid? do
      repo().transact_with fn -> # revert if email send fails
        repo().insert(cs)
        ~>> send_confirm_email(opts)
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
    do: login(changeset(:login, params, opts), opts)

  def login(%Changeset{data: %LoginFields{}}=cs, opts) do
    with {:ok, form} <- Changeset.apply_action(cs, :insert) do
      repo().find(login_query(form), cs)
      ~>> login_check_password(form, cs)
      ~>> login_check_confirmed(opts, cs)
      ~>> login_response()
    end
  end

  defp login_query(%{email: email}) when is_binary(email),
    do: Queries.login_by_email(email)

  defp login_query(%{username: username}) when is_binary(username),
    do: Queries.login_by_username(username)

  defp login_check_password(nil, _form, changeset) do
    Credential.dummy_check()
    {:error, Changeset.add_error(changeset, :form, "no_match")}
  end

  defp login_check_password(%Account{}=account, form, changeset) do
    if Credential.check_password(form.password, account.credential.password_hash),
      do: {:ok, account},
      else: {:error, Changeset.add_error(changeset, :form, "no_match")}
  end

  defp login_check_confirmed(%Account{}=account, opts, cs) do
    if is_nil(account.email.confirmed_at) and Email.must_confirm?(opts),
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

  ### request_confirm_email

  def request_confirm_email(params_or_changeset_or_form_or_account, opts \\ [])

  def request_confirm_email(%Changeset{data: %ConfirmEmailFields{}}=cs, opts),
    do: Changeset.apply_action(cs, :insert) ~>> rce_check_valid(cs, opts)

  def request_confirm_email(%Changeset{data: %ForgotPasswordFields{}}=cs, opts),
    do: Changeset.apply_action(cs, :insert) ~>> rce_check_valid(cs, opts)

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
    do: rec_check_what_to_do(account, changeset, opts)

  defp rec_check_what_to_do(account, changeset, opts) do

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

  defp resend_confirm_email(%Account{email: %{}=email}=account, opts) do
    with {:ok, _} <- mailer().send_now(Mails.confirm_email(account, opts), email.email_address),
      do: {:ok, :resent, account}
  end

  defp refresh_confirm_email(%Account{email: %Email{}=email}=account, opts) do
    with {:ok, email} <- repo().update(Email.put_token(email)),
         account = %{ account | email: email },
         {:ok, _} <- send_confirm_email(account, opts),
      do: {:ok, :refreshed, account}
  end

  ### confirm_email

  def confirm_email(account_or_token, opts \\ [])

  def confirm_email(%Account{}=account, _opts) do
    with {:ok, email} <- repo().update(Email.confirm(account.email)),
      do: {:ok, %{ account | email: email } }
  end

  def confirm_email(token, opts) when is_binary(token) do
    repo().transact_with fn ->
      repo().single(Queries.confirm_email(token))
      ~>> ce(opts)
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

  defp send_confirm_email(%Account{}=account, opts) do
    send_confirm_email(Email.must_confirm?(opts), account, opts)
  end

  defp send_confirm_email(false, account, _opts),
   do: {:ok, account}

  defp send_confirm_email(true, %Account{email: %{email_address: email_address}}=account, opts) do
    account = repo().preload(account, :email)
    mail = Mails.confirm_email(account, opts)
    mailer().send_now(mail, email_address)
    |> mailer_response(account)
  end

  defp send_confirm_email(_, _account, _opts),
   do: {:error, :email_missing}


  def request_forgot_password(params) do
    request_confirm_email(params, confirm_action: :forgot_password)
  end

  ## misc

  defp mailer_response({:ok, _}, account), do: {:ok, account}
  defp mailer_response({:error, error}, _) when is_atom(error), do: {:error, error}
  defp mailer_response(_, _), do: {:error, :email}

  def is_first_account? do
    Queries.count() <1
  end

  def instance_is_invite_only? do
    Config.get(:env) != :test
    and
    System.get_env("INVITE_ONLY", "true") in ["true", true]
  end


end
