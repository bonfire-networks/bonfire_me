defmodule Bonfire.Me.UsersTest do
  use Bonfire.Me.DataCase, async: true
  import Bonfire.Files.Simulation

  alias Bonfire.Me.Fake
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Users
  alias Bonfire.Me.Characters
  alias Bonfire.Data.Identity.Account

  defp admin_account?(account_id) do
    Account |> repo().get!(account_id) |> repo().preload(:instance_admin) |> Accounts.is_admin?()
  end

  defp admin_display_user_id(account_id) do
    Account
    |> repo().get!(account_id)
    |> repo().preload(:instance_admin)
    |> e(:instance_admin, :user_id, nil)
  end

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

      # last-seen is recorded per-profile as subject=account, object=user (see issue #2220)
      refute Bonfire.Social.Seen.last_date(account_id, user_id)
      refute Bonfire.Social.Seen.last_date(user_id, account_id)
      refute Bonfire.Social.Seen.last_date(account_id, account_id)

      assert {:ok, %{id: account_id}, %{id: user_id}} =
               Accounts.login(%{
                 email_or_username: user.character.username,
                 password: attrs.credential.password
               })

      last_datetime = Bonfire.Social.Seen.last_date(account_id, user_id)
      assert DateTime.to_date(last_datetime) == Date.utc_today()

      refute Bonfire.Social.Seen.last_date(user_id, account_id)
      refute Bonfire.Social.Seen.last_date(account_id, account_id)
    end
  end

  describe "transfer_to_account/3" do
    test "moves the profile from one account to another, and it stays a Person (no Organisation conversion)" do
      assert {:ok, account_a} = Accounts.signup(signup_form())
      assert {:ok, account_b} = Accounts.signup(signup_form())
      assert {:ok, user} = Users.create(create_user_form(), account_a)

      # precondition: owned by A, not B
      assert Enum.any?(Users.by_account(account_a), &(&1.id == user.id))
      refute Enum.any?(Users.by_account(account_b), &(&1.id == user.id))
      refute Bonfire.Common.URIs.shared_user?(user)

      assert {:ok, _} = Users.transfer_to_account(user, account_b)

      # now owned by B, no longer by A
      refute Enum.any?(Users.by_account(account_a), &(&1.id == user.id))
      assert Enum.any?(Users.by_account(account_b), &(&1.id == user.id))
      # still a Person — transfer never touches the shared_user mixin
      refute Bonfire.Common.URIs.shared_user?(repo().preload(user, :shared_user, force: true))
    end

    test "enforces the target account's max_per_account by default" do
      Process.put([:bonfire_me, Bonfire.Me.Users, :max_per_account], 1)
      on_exit(fn -> Process.delete([:bonfire_me, Bonfire.Me.Users, :max_per_account]) end)

      assert {:ok, account_a} = Accounts.signup(signup_form())
      assert {:ok, account_b} = Accounts.signup(signup_form())
      # fill B to its cap of 1
      assert {:ok, _b_user} = Users.create(create_user_form(), account_b)
      assert {:ok, user} = Users.create(create_user_form(), account_a)

      assert catch_throw(Users.transfer_to_account(user, account_b))
      # unchanged: still owned by A
      assert Enum.any?(Users.by_account(account_a), &(&1.id == user.id))
    end

    test "an admin profile: by default the source keeps admin, the moved profile is no longer admin, and the stale display-user link is cleared" do
      assert {:ok, account_a} = Accounts.signup(signup_form())
      assert {:ok, user} = Users.create(create_user_form(), account_a)
      assert {:ok, user} = Users.make_admin(user)
      assert admin_account?(account_a.id)
      assert admin_display_user_id(account_a.id) == user.id

      assert {:ok, account_b} = Accounts.signup(signup_form())
      refute admin_account?(account_b.id)

      assert {:ok, _moved} = Users.transfer_to_account(user, account_b)

      # source stays admin, but its now-foreign displayed-admin link is cleared
      assert admin_account?(account_a.id)
      assert admin_display_user_id(account_a.id) == nil
      # destination is not admin → the moved profile is no longer admin
      refute admin_account?(account_b.id)
    end

    test "an admin profile with transfer_admin: demotes the source and grants the destination" do
      assert {:ok, account_a} = Accounts.signup(signup_form())
      assert {:ok, user} = Users.create(create_user_form(), account_a)
      assert {:ok, user} = Users.make_admin(user)
      assert {:ok, account_b} = Accounts.signup(signup_form())

      assert {:ok, _moved} = Users.transfer_to_account(user, account_b, transfer_admin: true)

      refute admin_account?(account_a.id)
      assert admin_account?(account_b.id)
    end

    test "bypasses max_per_account when skip_max_per_account is passed (admin override)" do
      Process.put([:bonfire_me, Bonfire.Me.Users, :max_per_account], 1)
      on_exit(fn -> Process.delete([:bonfire_me, Bonfire.Me.Users, :max_per_account]) end)

      assert {:ok, account_a} = Accounts.signup(signup_form())
      assert {:ok, account_b} = Accounts.signup(signup_form())
      assert {:ok, _b_user} = Users.create(create_user_form(), account_b)
      assert {:ok, user} = Users.create(create_user_form(), account_a)

      assert {:ok, _} = Users.transfer_to_account(user, account_b, skip_max_per_account: true)
      assert Enum.any?(Users.by_account(account_b), &(&1.id == user.id))
    end
  end

  describe "local_by_id_or_username/1" do
    test "resolves a local user by bare username, @username, id, and name@local-domain" do
      assert {:ok, account} = Accounts.signup(signup_form())
      assert {:ok, user} = Users.create(create_user_form(), account)
      username = user.character.username
      local = Bonfire.Common.URIs.base_domain()

      for input <- [username, "@" <> username, user.id, "#{username}@#{local}"] do
        assert %{id: uid} = Users.local_by_id_or_username(input),
               "expected to resolve #{inspect(input)}"

        assert uid == user.id
      end
    end

    test "rejects a remote handle, an email, and an unknown username" do
      refute Users.local_by_id_or_username("nobody_#{System.unique_integer([:positive])}")
      refute Users.local_by_id_or_username("someone@remote.example.social")
      refute Users.local_by_id_or_username("someone@example.com")
    end
  end

  describe "search/2" do
    test "falls back to a DB query when the search index returns no results" do
      name = "searchablefallback#{System.unique_integer([:positive])}"
      user = Fake.fake_user!(%{}, %{name: name})

      results = Users.search(name)

      assert is_list(results)
      assert Enum.any?(results, &(Bonfire.Common.Enums.id(&1) == user.id))
    end

    test "returns results with profile and character preloaded" do
      name = "searchablepreload#{System.unique_integer([:positive])}"
      user = Fake.fake_user!(%{}, %{name: name})

      result = Users.search(name) |> Enum.find(&(Bonfire.Common.Enums.id(&1) == user.id))

      assert result
      assert e(result, :profile, :name, nil) == name
      assert e(result, :character, :username, nil)
    end
  end
end
