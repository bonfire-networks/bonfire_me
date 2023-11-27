defmodule Bonfire.Me.UsersTest do
  use Bonfire.Me.DataCase, async: true
  alias Bonfire.Me.Fake
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Users
  alias Bonfire.Me.Characters

  test "creation works" do
    assert {:ok, account} = Accounts.signup(signup_form())
    attrs = create_user_form()
    assert {:ok, user} = Users.create(attrs, account)
    user = repo().preload(user, [:profile, :character])
    assert Characters.clean_username(attrs.character.username) == user.character.username
    assert attrs.profile.name == user.profile.name
    assert attrs.profile.summary == user.profile.summary
  end

  test "usernames must be unique" do
    assert {:ok, account} = Accounts.signup(signup_form())
    attrs = create_user_form()
    assert {:ok, _user} = Users.create(attrs, account)
    assert {:error, changeset} = Users.create(attrs, account)
    assert %{character: character, profile: profile} = changeset.changes
    assert profile.valid?
    assert([username: {_, _}] = character.errors)
  end

  test "fetching by username" do
    assert {:ok, account} = Accounts.signup(signup_form())
    attrs = create_user_form()
    assert {:ok, _user} = Users.create(attrs, account)
    username = Characters.clean_username(attrs.character.username)
    assert {:ok, user} = Users.by_username(username)
    assert user.character.username == username
    assert user.profile.name == attrs.profile.name
    assert user.profile.summary == attrs.profile.summary
  end

  test "deletion works" do
    Oban.Testing.with_testing_mode(:inline, fn ->
      assert {:ok, account} = Accounts.signup(signup_form())
      attrs = create_user_form()
      username = Characters.clean_username(attrs.character.username)

      assert {:ok, user} = Users.create(attrs, account)
      assert Users.by_username!(username)

      {:ok, _} =
        Users.enqueue_delete(user)
        |> debug("del?")

      refute Users.by_username!(username)
    end)
  end

  test "deletion an account also deletes its users" do
    Oban.Testing.with_testing_mode(:inline, fn ->
      assert {:ok, account} = Accounts.signup(signup_form())

      attrs = create_user_form()
      username = Characters.clean_username(attrs.character.username)

      assert {:ok, user} = Users.create(attrs, account)

      {:ok, _} =
        Accounts.enqueue_delete(account)
        |> debug("del?")

      refute Accounts.get_current(Enums.id(account))
      refute Users.by_username!(username)
    end)
  end

  # test "can make a user an admin" do
  #   # FIXME: admin is now linked to Account
  #   assert {:ok, account} = Accounts.signup(signup_form())
  #   # first user is automatically admin (but not in test env)
  #   assert {:ok, fist_user} = Users.create(create_user_form(), account)
  #   refute Users.is_admin?(fist_user)
  #   assert {:ok, second_user} = Users.create(create_user_form(), account)
  #   refute Users.is_admin?(second_user)
  #   assert {:ok, second_user} = Users.make_admin(second_user)
  #   assert second_user.instance_admin.is_instance_admin
  #   assert {:ok, second_user} = Users.by_id(second_user.id)
  #   assert Users.is_admin?(second_user)
  # end
end
