defmodule Bonfire.Me.UsersTest do

  use Bonfire.DataCase, async: true
  alias Bonfire.Me.Fake
  alias Bonfire.Me.{Accounts, Users}
  alias Bonfire.Repo

  test "creation works" do
    assert {:ok, account} = Accounts.signup(Fake.signup_form())
    attrs = Fake.create_user_form()
    assert {:ok, user} = Users.create(attrs, account)
    user = Repo.preload(user, [:profile, :character])
    assert attrs.character.username == user.character.username
    assert attrs.profile.name == user.profile.name
    assert attrs.profile.summary == user.profile.summary
  end

  test "usernames must be unique" do
    assert {:ok, account} = Accounts.signup(Fake.signup_form())
    attrs = Fake.create_user_form()
    assert {:ok, _user} = Users.create(attrs, account)
    assert {:error, changeset} = Users.create(attrs, account)
    assert %{character: character, profile: profile} = changeset.changes
    assert profile.valid?
    assert([username: {_,_}] = character.errors)
  end

  test "fetching by username" do
    assert {:ok, account} = Accounts.signup(Fake.signup_form())
    attrs = Fake.create_user_form()
    assert {:ok, _user} = Users.create(attrs, account)
    assert {:ok, user} = Users.by_username(attrs.character.username)
    assert user.character.username == attrs.character.username
    assert user.profile.name == attrs.profile.name
    assert user.profile.summary == attrs.profile.summary
  end

  test "can make a user an admin" do
    # # first user is always admin
    # assert {:ok, account} = Accounts.signup(Fake.signup_form())
    # assert {:ok, first_user} = Users.create(Fake.create_user_form(), account)
    # assert Users.is_admin(first_user)

    assert {:ok, account} = Accounts.signup(Fake.signup_form())
    assert {:ok, second_user} = Users.create(Fake.create_user_form(), account)
    refute Users.is_admin(second_user)
    assert Users.make_admin(second_user).instance_admin.is_instance_admin
    assert {:ok, second_user} = Users.by_id(second_user.id)
    assert Users.is_admin(second_user)
  end
end
