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

  test "when user is deleted, also delete avatar file" do
    me = Fake.fake_user!()
    assert {:ok, upload} = Files.upload(IconUploader, me, icon_file())

    if path = Files.local_path(IconUploader, upload) do
      assert File.exists?(path)
    end || Bonfire.Common.Media.avatar_url(upload)

    {:ok, me} = Bonfire.Me.Profiles.set_profile_image(:icon, me, upload)

    assert {:ok, _} = Bonfire.Me.DeleteWorker.delete_structs_now(me)

    if path = Files.local_path(IconUploader, upload) do
      refute File.exists?(path)
    end
  end

  test "first user is automatically promoted to admin" do
    # first user is automatically admin (but not in test env), so we change env for the sake of the test
    Process.put([:bonfire, :env], :prod)
    on_exit(fn -> Process.delete([:bonfire, :env]) end)
    assert {:ok, account} = Accounts.signup(signup_form())
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
