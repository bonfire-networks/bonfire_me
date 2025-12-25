defmodule Bonfire.Me.UsersTest do
  use Bonfire.Me.DataCase, async: true
  import Bonfire.Files.Simulation

  alias Bonfire.Me.Fake
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Users
  alias Bonfire.Me.Characters

  alias Bonfire.Files
  alias Bonfire.Files.IconUploader

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

  test "user creation blocked when max_per_account reached" do
    Process.put(
      [:bonfire_me, Bonfire.Me.Users, :max_per_account],
      1
    )

    assert {:ok, account} = Accounts.signup(signup_form())
    assert {:ok, _user} = Users.create(create_user_form(), account)
    assert catch_throw(Users.create(create_user_form(), account))
    Process.delete([:bonfire_me, Bonfire.Me.Users, :max_per_account])
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

  test "can create a user with avatar, and when user is deleted it also deletes avatar file" do
    %{user: me, upload: upload, path: path, url: url} =
      fake_user_with_avatar!()

    assert path || url,
           "Expected a path or URL for the uploaded file, got neither."

    assert {:ok, _} = Bonfire.Me.DeleteWorker.delete_structs_now(me)

    if path do
      refute File.exists?(path)
    end
  end

  test "first user is automatically promoted to admin" do
    # first user is automatically admin (but not in test env), so we change env for the sake of the test
    Process.put([:bonfire, :env], :prod)
    on_exit(fn -> Process.delete([:bonfire, :env]) end)
    # explicitly set is_first_account? to bypass the count check which can be affected by other async tests
    assert {:ok, account} = Accounts.signup(signup_form(), is_first_account?: true)
    assert Accounts.is_admin?(account)
    attrs = create_user_form()
    assert {:ok, user} = Users.create(attrs, account)
    assert Accounts.is_admin?(user)
  end

  describe "login" do
    test "by: :username" do
      attrs = signup_form()
      assert {:ok, %{id: account_id} = account} = Accounts.signup(attrs)
      attrs_u = create_user_form()
      assert {:ok, %{id: user_id} = user} = Users.create(attrs_u, account)

      assert {:ok, %{id: account_id}, %{id: user_id}} =
               Accounts.login(%{
                 email_or_username: user.character.username,
                 password: attrs.credential.password
               })
    end

    test "updates the last_login / last seen date" do
      attrs = signup_form()
      assert {:ok, %{id: account_id} = account} = Accounts.signup(attrs, must_confirm?: false)

      attrs_u = create_user_form()
      assert {:ok, %{id: user_id} = user} = Users.create(attrs_u, account)

      refute Bonfire.Social.Seen.last_date(user_id, account_id)
      refute Bonfire.Social.Seen.last_date(account_id, account_id)
      refute Bonfire.Social.Seen.last_date(account_id, user_id)

      assert {:ok, %{id: account_id}, %{id: user_id}} =
               Accounts.login(%{
                 email_or_username: user.character.username,
                 password: attrs.credential.password
               })

      last_datetime = Bonfire.Social.Seen.last_date(user_id, account_id)
      assert DateTime.to_date(last_datetime) == Date.utc_today()

      refute Bonfire.Social.Seen.last_date(account_id, account_id)
      refute Bonfire.Social.Seen.last_date(account_id, user_id)
    end
  end
end
