defmodule Bonfire.Me.InstanceAdminPermissionTest do
  @moduledoc "Changing who is an instance admin or moderator, or moving a profile to another account, is checked in the context functions: only an instance admin acting as `current_user` may, or the caller says `skip_boundary_check: true` (no person acts). With neither, they refuse with `{:error, :not_permitted}`."
  use Bonfire.Me.DataCase, async: true
  @moduletag :backend

  import Ecto.Query, only: [from: 2]

  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Fake
  alias Bonfire.Me.Users

  defp admin! do
    {:ok, admin} = Users.make_admin(Fake.fake_user!(), skip_boundary_check: true)
    admin
  end

  # the account's admin flag, read from the database
  defp admin?(user) do
    user
    |> repo().preload([accounted: [account: :instance_admin]], force: true)
    |> e(:accounted, :account, nil)
    |> Accounts.is_admin?()
  end

  describe "is_admin!/1" do
    test "answers from the admin flag loaded with the user's account" do
      admin = admin!() |> repo().preload([accounted: [account: :instance_admin]], force: true)
      admin = Map.put(admin, :account, e(admin, :accounted, :account, nil))
      user = Fake.fake_user!() |> repo().preload(accounted: [account: :instance_admin])
      user = Map.put(user, :account, e(user, :accounted, :account, nil))

      assert Accounts.is_admin!(admin) == true
      assert Accounts.is_admin!(user) == false
    end

    test "a user whose admin flag isn't loaded is an error in tests, rather than a silent `false`" do
      admin = admin!() |> Map.put(:account, %Ecto.Association.NotLoaded{})

      assert_raise RuntimeError, ~r/preload instance_admin/, fn ->
        Accounts.is_admin!(admin)
      end
    end

    # the same shapes `is_admin?/1` reads, eg. a LiveView's `@__context__`
    test "answers from a context's current user or current account, as is_admin? does" do
      admin = admin!() |> repo().preload([accounted: [account: :instance_admin]], force: true)
      account = e(admin, :accounted, :account, nil)
      admin = Map.put(admin, :account, account)

      for context <- [
            %{current_user: admin},
            %{current_account: account},
            %{current_user: admin, current_account: account}
          ] do
        assert Accounts.is_admin?(context) == true,
               "control: is_admin? reads #{inspect(Map.keys(context))}"

        assert Accounts.is_admin!(context) == true,
               "is_admin! reads #{inspect(Map.keys(context))}"
      end

      unloaded = Map.put(admin, :account, repo().get!(Bonfire.Data.Identity.Account, account.id))

      assert_raise RuntimeError, ~r/preload instance_admin/, fn ->
        Accounts.is_admin!(%{current_user: unloaded})
      end
    end
  end

  test "the current user loaded for a session has their account's admin flag loaded" do
    account = Fake.fake_account!()
    {:ok, admin} = Users.make_admin(Fake.fake_user!(account), skip_boundary_check: true)

    for {how, user} <- [
          {"get_current/2", Users.get_current(admin.id, account.id)},
          {"get_current/1", Users.get_current(admin.id)}
        ] do
      assert %Bonfire.Data.Identity.Account{} = user.account,
             "#{how} didn't load the user's account"

      refute match?(%Ecto.Association.NotLoaded{}, user.account.instance_admin),
             "#{how} left the account's admin flag unloaded"

      assert Accounts.is_admin?(user) == true, "#{how}: the admin reads as not an admin"
    end
  end

  test "an admin can make someone an admin, and revoke them (control)" do
    admin = admin!()
    target = Fake.fake_user!()
    refute admin?(target)

    assert {:ok, _} = Users.make_admin(target, current_user: admin)
    assert admin?(target)

    assert {:ok, _} = Users.revoke_admin(target, current_user: admin)
    refute admin?(target)
  end

  test "an admin can make someone a moderator, and revoke them (control)" do
    admin = admin!()
    target = Fake.fake_user!()

    assert {:ok, _} = Users.make_moderator(target, current_user: admin)
    assert target.id in Enum.map(Users.list_moderators(), & &1.id)

    assert {:ok, _} = Users.revoke_moderator(target, current_user: admin)
    refute target.id in Enum.map(Users.list_moderators(), & &1.id)
  end

  test "an admin can transfer a profile to another account (control)" do
    admin = admin!()
    target_account = Fake.fake_account!()
    user = Fake.fake_user!()

    assert {:ok, _} = Users.transfer_to_account(user, target_account, current_user: admin)
    assert Enum.any?(Users.by_account(target_account), &(&1.id == user.id))
  end

  test "a non-admin cannot make someone an admin" do
    non_admin = Fake.fake_user!()
    target = Fake.fake_user!()

    assert {:error, :not_permitted} = Users.make_admin(target, current_user: non_admin)
    refute admin?(target)
  end

  test "a non-admin cannot revoke an admin" do
    non_admin = Fake.fake_user!()
    target = admin!()
    assert admin?(target)

    assert {:error, :not_permitted} = Users.revoke_admin(target, current_user: non_admin)
    assert admin?(target)
  end

  test "a non-admin cannot make or revoke a moderator" do
    non_admin = Fake.fake_user!()
    target = Fake.fake_user!()

    assert {:error, :not_permitted} = Users.make_moderator(target, current_user: non_admin)
    refute target.id in Enum.map(Users.list_moderators(), & &1.id)

    {:ok, _} = Users.make_moderator(target, skip_boundary_check: true)
    assert {:error, :not_permitted} = Users.revoke_moderator(target, current_user: non_admin)
    assert target.id in Enum.map(Users.list_moderators(), & &1.id)
  end

  test "a non-admin cannot transfer a profile to another account" do
    non_admin = Fake.fake_user!()
    target_account = Fake.fake_account!()
    user = Fake.fake_user!()

    assert {:error, :not_permitted} =
             Users.transfer_to_account(user, target_account, current_user: non_admin)

    refute Enum.any?(Users.by_account(target_account), &(&1.id == user.id))
  end

  test "a non-admin transferring to a missing or an existing target gets the same refusal" do
    non_admin = Fake.fake_user!()
    user = Fake.fake_user!()
    existing_account = Fake.fake_account!()

    assert {:error, :not_permitted} =
             Users.transfer_to_account(user.id, "nobody-here@example.local",
               current_user: non_admin
             )

    assert {:error, :not_permitted} =
             Users.transfer_to_account(user.id, id(existing_account), current_user: non_admin)
  end

  test "an admin transferring to a missing target gets :target_not_found, to an id it works" do
    admin = admin!()
    user = Fake.fake_user!()
    target_account = Fake.fake_account!()
    target_user = Fake.fake_user!(target_account)

    assert {:error, :target_not_found} =
             Users.transfer_to_account(user.id, "nobody-here@example.local", current_user: admin)

    # a user's id stands for that user's account
    assert {:ok, _} = Users.transfer_to_account(user.id, target_user.id, current_user: admin)
    assert Enum.any?(Users.by_account(target_account), &(&1.id == user.id))
  end

  # a user that has no account (eg. a service or remote character), as loaded from the database
  defp accountless_user! do
    user = Fake.fake_user!()

    {_, _} =
      repo().delete_all(from(a in Bonfire.Data.Identity.Accounted, where: a.id == ^user.id))

    {:ok, loaded} = Users.by_id(user.id)
    loaded
  end

  test "an acting user without an account is refused, not crashed on" do
    acting = accountless_user!()
    target = Fake.fake_user!()
    target_account = Fake.fake_account!()

    assert {:error, :not_permitted} = Users.make_admin(target, current_user: acting)
    assert {:error, :not_permitted} = Users.revoke_admin(target, current_user: acting)
    assert {:error, :not_permitted} = Users.make_moderator(target, current_user: acting)
    assert {:error, :not_permitted} = Users.revoke_moderator(target, current_user: acting)

    assert {:error, :not_permitted} =
             Users.transfer_to_account(target, target_account, current_user: acting)

    refute admin?(target)
  end

  test "a non-admin gets the same refusal for an existing and a missing username" do
    non_admin = Fake.fake_user!()
    target = Fake.fake_user!()
    username = e(target, :character, :username, nil)
    missing = "nobody_here_#{System.unique_integer([:positive])}"

    for fun <- [
          &Users.make_admin/2,
          &Users.revoke_admin/2,
          &Users.make_moderator/2,
          &Users.revoke_moderator/2
        ],
        name <- [username, missing] do
      assert {:error, :not_permitted} = fun.(name, current_user: non_admin)
    end

    refute admin?(target)
  end

  test "an admin loaded from the database without preloads can make someone an admin (control)" do
    admin = admin!()
    target = Fake.fake_user!()

    assert {:ok, _} = Users.make_admin(target, current_user: Users.get_current(admin.id)),
           "an admin loaded by get_current/1 was refused"

    {:ok, by_id} = Users.by_id(admin.id)

    assert {:ok, _} = Users.make_admin(target, current_user: by_id),
           "an admin loaded by by_id/1 was refused"

    assert admin?(target)
  end

  test "an admin can make and revoke admins and moderators by username (control)" do
    admin = admin!()
    target = Fake.fake_user!()
    username = e(target, :character, :username, nil)

    assert {:ok, _} = Users.make_admin(username, current_user: admin)
    assert admin?(target)
    assert {:ok, _} = Users.revoke_admin(username, current_user: admin)
    refute admin?(target)

    assert {:ok, _} = Users.make_moderator(username, current_user: admin)
    assert target.id in Enum.map(Users.list_moderators(), & &1.id)
    assert {:ok, _} = Users.revoke_moderator(username, current_user: admin)
    refute target.id in Enum.map(Users.list_moderators(), & &1.id)
  end

  test "with no user and no skip, they are refused" do
    target = Fake.fake_user!()
    target_account = Fake.fake_account!()

    assert {:error, :not_permitted} = Users.make_admin(target)
    assert {:error, :not_permitted} = Users.make_admin(target, moderator: true)
    assert {:error, :not_permitted} = Users.revoke_admin(target)
    assert {:error, :not_permitted} = Users.make_moderator(target)
    assert {:error, :not_permitted} = Users.revoke_moderator(target)
    assert {:error, :not_permitted} = Users.transfer_to_account(target, target_account)
    refute admin?(target)
  end
end
