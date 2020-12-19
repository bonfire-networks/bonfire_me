defmodule Bonfire.Me.Identity.Accounts do

  alias Bonfire.Data.Identity.{Account, Credential, Email, User}
  alias Bonfire.Common.Utils
  alias Bonfire.Me.Identity.Emails
  alias Bonfire.Me.Identity.Accounts.{
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

  def get_current(id) when is_binary(id),
    do: repo().one(Queries.current(id))

  def fetch_current(id) when is_binary(id),
    do: repo().single(Queries.current(id))

  @type changeset_name :: :change_password | :confirm_email | :login | :reset_password | :signup

  @spec changeset(changeset_name, attrs :: map) :: Changeset.t
  @spec changeset(changeset_name, attrs :: map, opts :: Keyword.t) :: Changeset.t
  def changeset(changeset_name, attrs, opts \\ [])

  def changeset(:change_password, attrs, _opts) when not is_struct(attrs),
    do: ChangePasswordFields.changeset(attrs)

  def changeset(:confirm_email, attrs, _opts) when not is_struct(attrs),
    do: ConfirmEmailFields.changeset(attrs)

  def changeset(:login, attrs, _opts) when not is_struct(attrs),
    do: LoginFields.changeset(attrs)

  def changeset(:reset_password, attrs, _opts) when not is_struct(attrs),
    do: ResetPasswordFields.changeset(attrs)

  def changeset(:signup, attrs, opts) do
    %Account{}
    |> Account.changeset(attrs)
    |> Changeset.cast_assoc(:email, with: &Email.changeset(&1, &2, opts))
    |> Changeset.cast_assoc(:credential)
  end

  ### signup

  def signup(thing, opts \\ [])

  def signup(attrs, opts) when not is_struct(attrs),
    do: signup(changeset(:signup, attrs, opts), opts)

  def signup(%Changeset{valid?: true, data: %Account{} = account}=cs, opts) do
    opts = opts ++ Email.config()
    repo().transact_with fn -> # revert if email send fails
      repo().insert(cs)
      ~>> maybe_send_confirm_email(opts)
    end
  end

  def signup(%Changeset{data: %Account{}}=cs, _), do: {:error, cs} # avoid checking out txn

  ### login

  def login(attrs_or_changeset, opts \\ [])

  def login(attrs, opts) when not is_struct(attrs),
    do: login(changeset(:login, attrs), opts)

  def login(%Changeset{data: %LoginFields{}}=cs, opts) do
    with {:ok, form} <- Changeset.apply_action(cs, :insert) do
      repo().single(Queries.login(form))
      ~>> check_password(form)
      ~>> check_confirmed(opts)
    end
  end

  defp check_password(nil, _form) do
    Argon2.no_user_verify()
    {:error, :not_found}
  end

  defp check_password(account, form) do
    if Argon2.verify_pass(form.password, account.credential.password_hash),
      do: {:ok, account},
      else: {:error, :not_found}
  end

  defp check_confirmed(%Account{email: %{confirmed_at: ca}}=account, opts) do
    if is_nil(ca) and Email.config(opts, :must_confirm, true),
      do: {:error, :email_not_confirmed},
      else: {:ok, account}
  end

  ### request_confirm_email

  def request_confirm_email(params_or_changeset_or_form_or_account, opts \\ [])

  def request_confirm_email(params, opts) when not is_struct(params),
    do: request_confirm_email(changeset(:confirm_email, params), opts)

  def request_confirm_email(%Changeset{data: %ConfirmEmailFields{}}=cs, opts),
    do: Changeset.apply_action(cs, :insert) ~>> request_confirm_email(opts)

  def request_confirm_email(%ConfirmEmailFields{}=form, opts) do
    if Email.config(opts, :must_confirm, true) do
      case repo().one(Queries.request_confirm_email(form.email)) do
        nil -> {:error, :not_found}
        %Account{email: email}=account -> request_confirm_email(account, opts)
      end
    else
      {:error, :confirmation_disabled}
    end
  end

  def request_confirm_email(%Account{email: %{}=email}=account, opts) do
    cond do
      not is_nil(email.confirmed_at) -> {:error, :confirmed}

      not Email.config(opts, :must_confirm, true) ->
        {:error, :confirmation_disabled}

      # why not refresh here? it provides a window of DOS opportunity
      # against a user completing their activation.
      future?(email.confirm_until) ->
        with {:ok, _} <- mailer().send_now(Emails.confirm_email(account), email.email_address),
          do: {:ok, :resent, account}

      true ->
        account = refresh_confirm_email_token(account)
        with {:ok, _} <- maybe_send_confirm_email(account, opts),
          do: {:ok, :refreshed, account}
    end
  end

  defp refresh_confirm_email_token(%Account{email: %Email{}=email}=account) do
    with {:ok, email} <- repo().update(Email.put_token(email)),
      do: {:ok, %{ account | email: email }}
  end

  ### confirm_email

  def confirm_email(%Account{}=account) do
    with {:ok, email} <- repo().update(Email.confirm(account.email)),
      do: {:ok, %{ account | email: email } }
  end

  def confirm_email(token) when is_binary(token) do
    repo().transact_with fn ->
      repo().one(Queries.confirm_email(token))
      |> do_confirm_email()
    end
  end

  defp do_confirm_email(nil), do: {:error, :not_found}
  defp do_confirm_email(%Account{email: %Email{}=email}=account) do
    cond do
      not is_nil(email.confirmed_at) -> {:error, :confirmed, account}
      is_nil(email.confirm_until) -> {:error, :no_expiry, account}
      future?(email.confirm_until) -> confirm_email(account)
      true -> {:error, :expired, account}
    end
  end

  defp maybe_send_confirm_email(%Account{}=account, opts) do
    if Keyword.get(opts, :must_confirm, true),
      do: repo().preload(account, :email) |> send_confirm_email(),
      else: {:ok, account}
  end

  defp send_confirm_email(%Account{email: %{email_address: email_address}}=account) do
    mail = Emails.confirm_email(account)
    mailer().send_now(mail, email_address)
    |> mailer_response(account)
  end

  defp mailer_response({:ok, _}, account), do: {:ok, account}
  defp mailer_response(_, _), do: {:error, :email}

  defp future?(%DateTime{}=dt) do
    DateTime.compare(DateTime.utc_now(), dt) == :lt
  end

end
