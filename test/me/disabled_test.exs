defmodule Bonfire.Me.DisabledTest do
  use Bonfire.Me.DataCase, async: true
  import Bonfire.Me.Integration
  alias Bonfire.Data.Identity.Credential
  alias Bonfire.Me.Fake
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Users

  # WIP: test login on an account that has a user that was disabled/blocked by admin

  describe "attempt login by disabled / instance-wide blocked account" do
    test "with single user, by: email" do
      attrs = signup_form()
      assert {:ok, account} = Accounts.signup(attrs)
      {:ok, _} = Accounts.confirm_email(account)

      user_attrs = create_user_form()
      assert {:ok, user} = Users.create(user_attrs, account)

      {:ok, _} = Bonfire.Boundaries.Blocks.block(user, :ghost, :instance_wide)
      {:ok, _} = Bonfire.Boundaries.Blocks.block(user, :silence, :instance_wide)

      assert catch_throw(
               Accounts.login(%{
                 email_or_username: attrs.email.email_address,
                 password: attrs.credential.password
               })
             ) == :inactive_user
    end

    test "with multiple users, by: blocked username" do
      attrs = signup_form()
      assert {:ok, account} = Accounts.signup(attrs)
      {:ok, _} = Accounts.confirm_email(account)

      user_attrs = create_user_form()
      assert {:ok, _user} = Users.create(user_attrs, account)

      user_attrs = create_user_form()
      assert {:ok, user} = Users.create(user_attrs, account)

      {:ok, _} = Bonfire.Boundaries.Blocks.block(user, :ghost, :instance_wide)
      {:ok, _} = Bonfire.Boundaries.Blocks.block(user, :silence, :instance_wide)

      assert catch_throw(
               Accounts.login(%{
                 email_or_username: user.character.username,
                 password: attrs.credential.password
               })
               |> debug()
             ) == :inactive_user
    end

    test "with multiple users, by: email" do
      attrs = signup_form()
      assert {:ok, account} = Accounts.signup(attrs)
      {:ok, _} = Accounts.confirm_email(account)

      user_attrs = create_user_form()
      assert {:ok, _user} = Users.create(user_attrs, account)

      user_attrs = create_user_form()
      assert {:ok, user} = Users.create(user_attrs, account)

      {:ok, _} = Bonfire.Boundaries.Blocks.block(user, :ghost, :instance_wide)
      {:ok, _} = Bonfire.Boundaries.Blocks.block(user, :silence, :instance_wide)

      assert catch_throw(
               Accounts.login(%{
                 email_or_username: attrs.email.email_address,
                 password: attrs.credential.password
               })
             ) == :inactive_user
    end

    test "with multiple users, by: non-blocked username" do
      attrs = signup_form()
      assert {:ok, account} = Accounts.signup(attrs)
      {:ok, _} = Accounts.confirm_email(account)

      user_attrs = create_user_form()
      assert {:ok, user1} = Users.create(user_attrs, account)

      user_attrs = create_user_form()
      assert {:ok, user2} = Users.create(user_attrs, account)

      {:ok, _} = Bonfire.Boundaries.Blocks.block(user1, :ghost, :instance_wide)
      {:ok, _} = Bonfire.Boundaries.Blocks.block(user1, :silence, :instance_wide)

      assert catch_throw(
               Accounts.login(%{
                 email_or_username: user2.character.username,
                 password: attrs.credential.password
               })
               |> debug()
             ) == :inactive_user
    end
  end

  test "attempt signup on account with another blocked user" do
    attrs = signup_form()
    assert {:ok, account} = Accounts.signup(attrs)
    {:ok, _} = Accounts.confirm_email(account)

    user_attrs = create_user_form()
    assert {:ok, user} = Users.create(user_attrs, account)

    {:ok, _} = Bonfire.Boundaries.Blocks.block(user, :ghost, :instance_wide)
    {:ok, _} = Bonfire.Boundaries.Blocks.block(user, :silence, :instance_wide)

    user_attrs = create_user_form()
    assert catch_throw(Users.create(user_attrs, account)) == :inactive_user
  end
end
