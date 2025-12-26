defmodule Bonfire.Me.AccountsTest do
  use Bonfire.Me.DataCase, async: true
  import Bonfire.Me.Integration
  alias Bonfire.Data.Identity.Credential
  alias Bonfire.Me.Fake
  alias Bonfire.Me.Accounts

  setup do
    Bonfire.Me.Fake.clear_caches()
    :ok
  end

  describe "signup" do
    test "email: :valid, with must_confirm?: true" do
      attrs = signup_form()
      assert {:ok, account} = Accounts.signup(attrs, must_confirm?: true)

      assert Credential.check_password(
               attrs.credential.password,
               account.credential.password_hash
             )

      assert account.email.email_address == attrs.email.email_address
      assert account.email.confirm_token
      assert account.email.confirm_until
      assert nil == account.email.confirmed_at
    end

    test "email: :valid, with must_confirm?: false" do
      attrs = signup_form()
      assert {:ok, account} = Accounts.signup(attrs, must_confirm?: false)
      assert account.email.email_address == attrs.email.email_address
      assert account.email.confirmed_at
      assert nil == account.email.confirm_token
      assert nil == account.email.confirm_until

      assert Credential.check_password(
               attrs.credential.password,
               account.credential.password_hash
             )
    end

    test "email: :valid, without specifying must_confirm? (meaning must confirm after the first signup)" do
      attrs = signup_form()
      assert {:ok, account} = Accounts.signup(attrs)
      assert account.email.email_address == attrs.email.email_address
      # assert account.email.confirmed_at
      assert nil == account.email.confirm_token
      assert nil == account.email.confirm_until

      assert Credential.check_password(
               attrs.credential.password,
               account.credential.password_hash
             )

      # clear caches just in case
      Bonfire.Me.Fake.clear_caches()

      attrs = signup_form()
      assert {:ok, account} = Accounts.signup(attrs)
      assert account.email.email_address == attrs.email.email_address

      # FIXME!
      assert account.email.confirm_token
      assert account.email.confirm_until
      assert nil == account.email.confirmed_at

      assert Credential.check_password(
               attrs.credential.password,
               account.credential.password_hash
             )
    end

    test "email: :exists" do
      attrs = signup_form()
      assert {:ok, account} = Accounts.signup(attrs, must_confirm?: true)
      assert account.email.email_address == attrs.email.email_address

      assert Credential.check_password(
               attrs.credential.password,
               account.credential.password_hash
             )

      assert {:error, changeset} = Accounts.signup(attrs)
      assert changeset.changes.email.errors[:email_address]
    end
  end

  describe "request_confirm_email" do
    test "resends a confirmation email" do
      attrs = signup_form()
      assert {:ok, account} = Accounts.signup(attrs, must_confirm?: true)

      assert {:ok, :resent, account} =
               Accounts.request_confirm_email(%{
                 email: attrs.email.email_address
               })

      assert account.email.confirm_token
      assert account.email.confirm_until
    end

    @tag :todo
    test "refresh the confirmation token and sends a new confirmation email" do
      attrs = signup_form()
      assert {:ok, account} = Accounts.signup(attrs, must_confirm?: true)

      # WIP: this is resending instead because confirm_until is still valid
      assert {:ok, :refreshed, account} =
               Accounts.request_confirm_email(%{
                 email: attrs.email.email_address
               })

      assert account.email.confirm_token
      assert account.email.confirm_until
    end

    test "fails for already confirmed emails" do
      attrs = signup_form()
      assert {:ok, account} = Accounts.signup(attrs, must_confirm?: true)
      assert {:ok, account} = Accounts.confirm_email(account)

      assert {:error, changeset} =
               Accounts.request_confirm_email(%{
                 email: attrs.email.email_address
               })

      assert [form: {"already_confirmed", []}] = changeset.errors
    end
  end

  describe "confirm_email" do
    test "with: :account" do
      attrs = signup_form()
      assert {:ok, account} = Accounts.signup(attrs, must_confirm?: true)
      assert {:ok, account} = Accounts.confirm_email(account)
      assert account.email.confirmed_at
      assert is_nil(account.email.confirm_token)
      assert {:ok, _account} = Accounts.confirm_email(account)
    end

    test "with: :token" do
      attrs = signup_form()
      assert {:ok, account} = Accounts.signup(attrs, must_confirm?: true)
      assert account.email.confirm_token

      assert {:ok, account} = Accounts.confirm_email(account.email.confirm_token)

      assert account.email.confirmed_at
      assert is_nil(account.email.confirm_token)
    end
  end

  describe "login" do
    # TODO: by username

    test "by: :email, confirmed: false" do
      attrs = signup_form()
      assert {:ok, _account} = Accounts.signup(attrs, must_confirm?: true)

      assert {:error, changeset} =
               Accounts.login(%{
                 email_or_username: attrs.email.email_address,
                 password: attrs.credential.password
               })

      assert changeset.errors[:form] == {"email_not_confirmed", []}
    end

    test "by: :email, with manual confirmation" do
      attrs = signup_form()
      assert {:ok, %{id: account_id} = account} = Accounts.signup(attrs, must_confirm?: true)
      {:ok, _} = Accounts.confirm_email(account)

      assert {:ok, %{id: account_id}, nil} =
               Accounts.login(%{
                 email_or_username: attrs.email.email_address,
                 password: attrs.credential.password
               })

      assert account.email.email_address == attrs.email.email_address
    end

    test "by: :email, confirmed: :auto" do
      attrs = signup_form()
      assert {:ok, %{id: account_id} = account} = Accounts.signup(attrs, must_confirm?: false)

      assert {:ok, %{id: account_id}, nil} =
               Accounts.login(%{
                 email_or_username: attrs.email.email_address,
                 password: attrs.credential.password
               })
    end

    test "by: :email, must_confirm?: true on signup but must_confirm?: false on login" do
      attrs = signup_form()
      assert {:ok, %{id: account_id} = account} = Accounts.signup(attrs, must_confirm?: true)

      assert {:ok, %{id: account_id}, nil} =
               Accounts.login(
                 %{
                   email_or_username: attrs.email.email_address,
                   password: attrs.credential.password
                 },
                 must_confirm?: false
               )
    end

    test "updates the last_login / last seen date" do
      attrs = signup_form()
      assert {:ok, %{id: account_id} = account} = Accounts.signup(attrs, must_confirm?: false)

      refute Bonfire.Social.Seen.last_date(account_id, account_id)

      assert {:ok, %{id: account_id}, nil} =
               Accounts.login(%{
                 email_or_username: attrs.email.email_address,
                 password: attrs.credential.password
               })

      last_datetime = Bonfire.Social.Seen.last_date(account_id, account_id)
      assert DateTime.to_date(last_datetime) == Date.utc_today()
    end
  end

  test "deletion works" do
    Oban.Testing.with_testing_mode(:inline, fn ->
      assert {:ok, account} = Accounts.signup(signup_form())
      assert Accounts.get_current(Enums.id(account))

      {:ok, _} =
        Accounts.enqueue_delete(account)
        |> debug("del?")

      refute Accounts.get_current(Enums.id(account))
    end)
  end
end
