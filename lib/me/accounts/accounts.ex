defmodule Bonfire.Me.Accounts do

  alias Bonfire.Data.Identity.{Account, Credential, Email, User}
  alias Bonfire.Common.Utils
  alias Bonfire.Me.Mails
  alias Bonfire.Me.Accounts.{
    ChangePasswordFields,
    ConfirmEmailFields,
    LoginFields,
    ResetPasswordFields,
    Queries,
  }
  alias Ecto.Changeset
  alias Pointers.Changesets
  import Bonfire.Me.Integration
  import Ecto.Query
  use OK.Pipe

  def get_current(nil), do: nil
  def get_current(id) when is_binary(id),
    do: repo().one(Queries.current(id))

  def fetch_current(id) when is_binary(id),
    do: repo().single(Queries.current(id))

  def get_by_email(email) when is_binary(email),
    do: repo().one(Queries.by_email(email))

  @type changeset_name :: :change_password | :confirm_email | :login | :reset_password | :signup

  @spec changeset(changeset_name, params :: map) :: Changeset.t
  @spec changeset(changeset_name, params :: map, opts :: Keyword.t) :: Changeset.t
  def changeset(changeset_name, params, opts \\ [])

  def changeset(:change_password, params, _opts) when not is_struct(params),
    do: ChangePasswordFields.changeset(params)

  def changeset(:confirm_email, params, _opts) when not is_struct(params),
    do: ConfirmEmailFields.changeset(params)

  def changeset(:login, params, _opts) when not is_struct(params),
    do: LoginFields.changeset(params)

  def changeset(:reset_password, params, _opts) when not is_struct(params),
    do: ResetPasswordFields.changeset(params)

  def changeset(:signup, params, opts) do
    %Account{}
    |> Account.changeset(params)
    |> Changeset.cast_assoc(:email, with: &Email.changeset(&1, &2, opts))
    |> Changeset.cast_assoc(:credential)
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

  def login(params_or_changeset, opts \\ [])

  def login(params, opts) when not is_struct(params),
    do: login(changeset(:login, params, opts), opts)

  def login(%Changeset{data: %LoginFields{}}=cs, opts) do
    with {:ok, form} <- Changeset.apply_action(cs, :insert) do
      repo().find(login_query(form), cs)
      ~>> login_check_password(form, cs)
      ~>> login_check_confirmed(opts, cs)
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

  ### request_confirm_email

  def request_confirm_email(params_or_changeset_or_form_or_account, opts \\ [])

  def request_confirm_email(params, opts) when not is_struct(params),
    do: request_confirm_email(changeset(:confirm_email, params, opts), opts)

  def request_confirm_email(%Changeset{data: %ConfirmEmailFields{}}=cs, opts),
    do: Changeset.apply_action(cs, :insert) ~>> rce_check_valid(cs, opts)

  defp rce_check_valid(form, %Changeset{}=changeset, opts),
    do: rce_check_confirm(Email.must_confirm?(opts), form, changeset, opts)


  defp rce_check_confirm(false, _form, changeset, _opts),
    do: {:error, Changeset.add_error(changeset, :form, "confirmation_disabled")}

  defp rce_check_confirm(true, form, changeset, opts) do
    repo().one(Queries.request_confirm_email(form.email))
    |> rce_check_account(form, changeset, opts)
  end


  defp rce_check_account(nil, form, changeset, opts),
    do: {:error, Changeset.add_error(changeset, :form, "not_found")}

  defp rce_check_account(%Account{}=account, form, changeset, opts),
    do: rce_check_permitted(account.email, changeset, opts)


  defp rce_check_permitted(account, changeset, opts) do
    case Email.may_request_confirm_email?(account.email, opts) do
      {:ok, :resend}  -> resend_confirm_email(account)
      {:ok, :refresh} -> refresh_confirm_email(account, opts)
      {:error, error} -> {:error, Changeset.add_error(changeset, :form, error)}
    end
  end

  defp resend_confirm_email(%Account{email: %{}=email}=account) do
    with {:ok, _} <- mailer().send_now(Mails.confirm_email(account), email.email_address),
      do: {:ok, :resent, account}
  end

  defp refresh_confirm_email(%Account{email: %Email{}=email}=account, opts) do
    with {:ok, email} <- repo().update(Email.put_token(email)),
         account = %{ account | email: email },
         {:ok, _} <- send_confirm_email(Mails.confirm_email(account), opts),
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
    with :ok <- Email.may_confirm?(account.email, opts),
      do: confirm_email(account)
  end

  defp send_confirm_email(%Account{}=account, opts) do
    send_confirm_email(Email.must_confirm?(opts), account, opts)
  end

  defp send_confirm_email(false, account, _opts),
   do: {:ok, account}

  defp send_confirm_email(true, account, _opts) do
    account = repo().preload(account, :email)
    mail = Mails.confirm_email(account)
    mailer().send_now(mail, account.email.email_address)
    |> mailer_response(account)
  end

  defp mailer_response({:ok, _}, account), do: {:ok, account}
  defp mailer_response(_, _), do: {:error, :email}


end
