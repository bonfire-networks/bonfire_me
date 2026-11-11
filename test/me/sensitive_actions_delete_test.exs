defmodule Bonfire.Me.SensitiveActionsDeleteTest do
  @moduledoc "Deleting a profile or an account through the sudo actions: by its owner, or by an instance admin once the target is blocked instance-wide."
  use Bonfire.Me.DataCase, async: false
  @moduletag :backend
  import Bonfire.Me.Fake

  alias Bonfire.Boundaries.Blocks
  alias Bonfire.Me.SensitiveActions.DeleteAccount
  alias Bonfire.Me.SensitiveActions.DeleteUser

  setup do
    admin_account = fake_account!()
    admin = fake_user!(admin_account)
    {:ok, _} = Bonfire.Me.Users.make_admin(admin)

    # the account as the controller holds it: nothing about the admin flag preloaded
    {:ok, admin_account: admin_account, admin: admin}
  end

  defp enqueued_ids do
    Oban.Testing.all_enqueued(Bonfire.Common.Repo, worker: Bonfire.Me.DeleteWorker)
    |> Enum.flat_map(& &1.args["ids"])
  end

  # a blocked account can't make more profiles, so any sibling must exist before this is called
  defp blocked_local_user!(account \\ fake_account!()) do
    user = fake_user!(account)
    {:ok, _} = Blocks.block(user, :block, scope: :instance_wide)
    assert Blocks.is_blocked?(user, :ghost, :instance_wide)
    user
  end

  defp remote_user!(blocked?) do
    Tesla.Mock.mock_global(fn env -> ActivityPub.Test.HttpRequestMock.request(env) end)
    Process.put(:federating, true)

    # creating the remote actor goes through ActivityPub's fetcher, which reads Application env rather than the process
    instance_config = Application.get_env(:activity_pub, :instance)
    Application.put_env(:activity_pub, :instance, Keyword.put(instance_config, :federating, true))
    on_exit(fn -> Application.put_env(:activity_pub, :instance, instance_config) end)

    {:ok, remote} = Bonfire.Federate.ActivityPub.Simulate.fake_remote_user()
    if blocked?, do: {:ok, _} = Blocks.block(remote, :block, scope: :instance_wide)
    remote
  end

  describe "DeleteUser as an instance admin" do
    test "deletes a user blocked instance-wide, local", %{admin_account: admin_account} do
      user = blocked_local_user!()
      assert {:ok, _} = DeleteUser.execute(%{account: admin_account, target_id: user.id})
      assert user.id in enqueued_ids()
    end

    test "deletes a user blocked instance-wide, remote", %{admin_account: admin_account} do
      remote = remote_user!(true)
      assert {:ok, _} = DeleteUser.execute(%{account: admin_account, target_id: remote.id})
      assert remote.id in enqueued_ids()
    end

    test "refuses a local user who isn't blocked", %{admin_account: admin_account} do
      user = fake_user!(fake_account!())

      assert {:error, _} = DeleteUser.execute(%{account: admin_account, target_id: user.id})
      refute user.id in enqueued_ids()
    end

    test "refuses a remote user who isn't blocked", %{admin_account: admin_account} do
      remote = remote_user!(false)

      assert {:error, _} = DeleteUser.execute(%{account: admin_account, target_id: remote.id})
      refute remote.id in enqueued_ids()
    end

    test "describes a blocked user as an admin delete, naming them", %{
      admin_account: admin_account
    } do
      user = blocked_local_user!()
      description = DeleteUser.describe(%{account: admin_account, target_id: user.id})

      assert description.title == "Delete this user"
      assert description.description =~ user.character.username
    end

    test "describes an unblocked user as not deletable yet", %{admin_account: admin_account} do
      user = fake_user!(fake_account!())
      description = DeleteUser.describe(%{account: admin_account, target_id: user.id})

      assert description.description =~ "Block"
      refute description.description =~ user.character.username
    end
  end

  # an admin target, blocked instance-wide: the block alone would allow the delete
  defp blocked_admin!(account \\ fake_account!()) do
    user = fake_user!(account)
    {:ok, _} = Bonfire.Me.Users.make_admin(user)
    {:ok, _} = Blocks.block(user, :block, scope: :instance_wide)
    user
  end

  describe "DeleteUser on a target who is an instance admin" do
    test "refuses, even blocked instance-wide", %{admin_account: admin_account} do
      target = blocked_admin!()

      assert {:error, _} = DeleteUser.execute(%{account: admin_account, target_id: target.id})
      refute target.id in enqueued_ids()
    end

    test "describes that their admin role must be revoked first", %{admin_account: admin_account} do
      target = blocked_admin!()
      description = DeleteUser.describe(%{account: admin_account, target_id: target.id})

      assert description.description =~ "revoke their admin role first"
      refute description.description =~ target.character.username
    end

    test "deletes them once their admin role is revoked", %{admin_account: admin_account} do
      target = blocked_admin!()
      {:ok, _} = Bonfire.Me.Users.revoke_admin(target)

      assert {:ok, _} = DeleteUser.execute(%{account: admin_account, target_id: target.id})
      assert target.id in enqueued_ids()
    end
  end

  describe "DeleteAccount on an account with an instance admin profile" do
    test "refuses, even blocked instance-wide", %{admin_account: admin_account} do
      account = fake_account!()
      target = blocked_admin!(account)

      assert {:error, _} = DeleteAccount.execute(%{account: admin_account, target_id: target.id})
      refute account.id in enqueued_ids()
    end

    test "refuses when it is a sibling profile that is the admin", %{admin_account: admin_account} do
      account = fake_account!()
      admin_sibling = fake_user!(account)
      {:ok, _} = Bonfire.Me.Users.make_admin(admin_sibling)
      blocked = blocked_local_user!(account)

      assert {:error, _} = DeleteAccount.execute(%{account: admin_account, target_id: blocked.id})
      refute account.id in enqueued_ids()
    end

    test "describes that their admin role must be revoked first", %{admin_account: admin_account} do
      target = blocked_admin!()
      description = DeleteAccount.describe(%{account: admin_account, target_id: target.id})

      assert description.description =~ "revoke their admin role first"
    end
  end

  describe "DeleteUser as anyone else" do
    test "a non-admin cannot delete someone else's blocked profile" do
      user = blocked_local_user!()
      other_account = fake_account!()
      _ = fake_user!(other_account)

      assert {:error, _} = DeleteUser.execute(%{account: other_account, target_id: user.id})
      refute user.id in enqueued_ids()
    end

    test "the owner still deletes their own profile, blocked or not" do
      account = fake_account!()
      user = fake_user!(account)

      assert {:ok, _} = DeleteUser.execute(%{account: account, target_id: user.id})
      assert user.id in enqueued_ids()
    end
  end

  describe "DeleteAccount as an instance admin" do
    test "deletes the account of a blocked profile with its other profiles", %{
      admin_account: admin_account
    } do
      account = fake_account!()
      other = fake_user!(account)
      blocked = blocked_local_user!(account)
      refute Blocks.is_blocked?(other, :ghost, :instance_wide)

      assert {:ok, _} = DeleteAccount.execute(%{account: admin_account, target_id: blocked.id})

      ids = enqueued_ids()
      assert account.id in ids
      assert blocked.id in ids
      assert other.id in ids
    end

    test "refuses the account of an unblocked profile", %{admin_account: admin_account} do
      account = fake_account!()
      user = fake_user!(account)

      assert {:error, _} = DeleteAccount.execute(%{account: admin_account, target_id: user.id})
      refute account.id in enqueued_ids()
    end

    test "refuses a remote user, who has no account here", %{admin_account: admin_account} do
      remote = remote_user!(true)

      assert {:error, _} = DeleteAccount.execute(%{account: admin_account, target_id: remote.id})
      refute remote.id in enqueued_ids()
    end

    test "a non-admin cannot delete another account" do
      target_account = fake_account!()
      user = blocked_local_user!(target_account)
      other_account = fake_account!()

      assert {:error, _} = DeleteAccount.execute(%{account: other_account, target_id: user.id})
      refute target_account.id in enqueued_ids()
    end

    test "without a target it stays the owner's own account delete" do
      account = fake_account!()
      user = fake_user!(account)

      assert {:ok, _} = DeleteAccount.execute(%{account: account})
      ids = enqueued_ids()
      assert account.id in ids
      assert user.id in ids
    end
  end

  describe "DeleteAccount.describe/1" do
    test "says how many profiles go with the account" do
      account = fake_account!()
      _ = fake_user!(account)
      _ = fake_user!(account)

      assert DeleteAccount.describe(%{account: account}).description =~ "2 profiles"
    end

    test "says 1 profile for an account with one" do
      account = fake_account!()
      _ = fake_user!(account)

      assert DeleteAccount.describe(%{account: account}).description =~ "1 profile"
    end

    test "keeps the general text when the context has no account" do
      assert DeleteAccount.describe(%{}).description =~ "all your profiles"
    end

    test "an admin's description counts the target's account profiles, not their own", %{
      admin_account: admin_account
    } do
      account = fake_account!()
      _ = fake_user!(account)
      _ = fake_user!(account)
      blocked = blocked_local_user!(account)

      description = DeleteAccount.describe(%{account: admin_account, target_id: blocked.id})
      assert description.description =~ "3 profiles"
    end
  end
end
