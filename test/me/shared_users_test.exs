defmodule Bonfire.Me.SharedUsersTest do
  @moduledoc """
  Unit 10 backend: a shared user (a team/organisation profile) is co-managed by several accounts,
  linked via its `caretaker_accounts`. Any linked account can add or remove other accounts.
  """
  use Bonfire.Me.DataCase, async: false

  alias Bonfire.Me.SharedUsers
  alias Bonfire.Me.Fake

  describe "managing the accounts linked to a shared user" do
    test "adding accounts appends them (does not replace), list_accounts reflects all, remove_account drops one" do
      # the org profile, created by account_a
      account_a = Fake.fake_account!()
      org = Fake.fake_user!(account_a)

      # two people invited to co-manage, each identified by their username -> account
      account_b = Fake.fake_account!()
      user_b = Fake.fake_user!(account_b)
      account_c = Fake.fake_account!()
      user_c = Fake.fake_user!(account_c)

      assert {:ok, _} = SharedUsers.add_account(org, "@" <> user_b.character.username)
      assert {:ok, _} = SharedUsers.add_account(org, "@" <> user_c.character.username)

      ids = SharedUsers.list_accounts(org) |> Enum.map(& &1.id)
      # both invited accounts are linked (i.e. the second add appended rather than replaced)
      assert account_b.id in ids
      assert account_c.id in ids

      assert {:ok, _} = SharedUsers.remove_user(org, "@" <> user_c.character.username)

      ids_after = SharedUsers.list_accounts(org) |> Enum.map(& &1.id)
      assert account_b.id in ids_after
      refute account_c.id in ids_after
    end

    test "only an account already linked to the shared user may add or remove co-managers" do
      creator = Fake.fake_account!()
      org = Fake.fake_user!(creator)
      member = Fake.fake_user!()

      # bootstrap: the creator creates the org (becoming its first linked account) and adds `member`
      assert {:ok, _} =
               SharedUsers.add_account(org, "@" <> member.character.username, %{},
                 current_account: creator
               )

      outsider = Fake.fake_account!()
      another = Fake.fake_user!(outsider)

      # an outsider (not a linked account) is refused
      assert {:error, _} =
               SharedUsers.add_account(org, "@" <> another.character.username, %{},
                 current_account: outsider
               )

      assert {:error, _} =
               SharedUsers.add_account(org, "@" <> another.character.username, %{},
                 current_user: another
               )

      assert {:error, _} =
               SharedUsers.remove_user(org, "@" <> member.character.username,
                 current_account: outsider
               )

      assert {:error, _} =
               SharedUsers.remove_user(org, "@" <> member.character.username,
                 current_user: another
               )

      # a linked account (the creator) is allowed
      assert {:ok, _} =
               SharedUsers.add_account(org, "@" <> another.character.username, %{},
                 current_account: creator
               )

      assert {:ok, _} =
               SharedUsers.remove_user(org, "@" <> member.character.username,
                 current_account: creator
               )

      assert {:ok, _} =
               SharedUsers.remove_user(org, "@" <> another.character.username,
                 current_user: another
               )
    end

    test "a co-manager is recorded by the invited user, so the roster never leaks the account's other personas" do
      account_a = Fake.fake_account!()
      org = Fake.fake_user!(account_a)

      # the invited person's account also owns another persona that must stay private
      member_account = Fake.fake_account!()
      invited = Fake.fake_user!(member_account)
      sibling = Fake.fake_user!(member_account)

      assert {:ok, _} =
               SharedUsers.add_account(org, "@" <> invited.character.username, %{},
                 current_account: account_a
               )

      # the display roster lists only the specifically invited user, not their account siblings
      usernames =
        SharedUsers.list_linked_users(org)
        |> Enum.map(&e(&1, :character, :username, nil))

      assert invited.character.username in usernames
      refute sibling.character.username in usernames

      # access remains account-level: the invited user's whole account is still a linked account
      assert member_account.id in (SharedUsers.list_accounts(org) |> Enum.map(& &1.id))
    end

    test "co-managers can only be invited by username, not by email (an email is account-ambiguous)" do
      account_a = Fake.fake_account!()
      org = Fake.fake_user!(account_a)

      member_account = Fake.fake_account!()
      _invited = Fake.fake_user!(member_account)
      email = member_account |> repo().maybe_preload(:email) |> e(:email, :email_address, nil)

      assert email
      assert {:error, _} = SharedUsers.add_account(org, email, %{}, current_account: account_a)
    end

    test "removing a co-manager is refused when it would leave the profile with no one managing it" do
      account_a = Fake.fake_account!()
      org = Fake.fake_user!(account_a)
      creator = Fake.fake_user!(account_a)

      # bootstrap: the creator's account becomes the sole linked account
      assert {:ok, _} =
               SharedUsers.add_account(org, "@" <> creator.character.username, %{},
                 current_user: creator
               )

      assert [_only] = SharedUsers.list_accounts(org)

      # cannot remove the last one
      assert {:error, _} =
               SharedUsers.remove_user(org, "@" <> creator.character.username,
                 current_user: creator
               )

      assert [_still] = SharedUsers.list_accounts(org)

      # but once a second account is linked, removing back down to one is allowed
      member_account = Fake.fake_account!()
      member = Fake.fake_user!(member_account)

      assert {:ok, _} =
               SharedUsers.add_account(org, "@" <> member.character.username, %{},
                 current_user: creator
               )

      assert {:ok, _} =
               SharedUsers.remove_user(org, "@" <> member.character.username,
                 current_user: creator
               )
    end

    test "a co-manager can be removed by account id (the roster already has it, so the UI passes the account id, no lookup)" do
      account_a = Fake.fake_account!()
      org = Fake.fake_user!(account_a)
      creator = Fake.fake_user!(account_a)

      member_account = Fake.fake_account!()
      member = Fake.fake_user!(member_account)

      assert {:ok, _} =
               SharedUsers.add_account(org, "@" <> creator.character.username, %{},
                 current_user: creator
               )

      assert {:ok, _} =
               SharedUsers.add_account(org, "@" <> member.character.username, %{},
                 current_user: creator
               )

      assert member_account.id in (SharedUsers.list_accounts(org) |> Enum.map(& &1.id))

      # remove by the member's account id directly (account-level removal)
      assert {:ok, _} = SharedUsers.remove_account(org, member_account.id, current_user: creator)

      refute member_account.id in (SharedUsers.list_accounts(org) |> Enum.map(& &1.id))
    end

    test "by_account works for an account that co-manages a shared user (regression: m2m preload must not crash)" do
      account_a = Fake.fake_account!()
      org = Fake.fake_user!(account_a)

      account_b = Fake.fake_account!()
      user_b = Fake.fake_user!(account_b)

      # link account_b as a co-manager of `org`, so account_b's `shared_users` assoc is populated
      assert {:ok, _} =
               SharedUsers.add_account(org, "@" <> user_b.character.username, %{},
                 current_account: account_a
               )

      # by_account must combine account_b's own users + the shared users it co-manages, without
      # crashing on the `shared_users` many_to_many preload (was: `++` on an unloaded assoc)
      ids = SharedUsers.by_account(account_b) |> Enum.map(& &1.id)
      assert user_b.id in ids
      assert org.id in ids
    end

    test "the persona chosen at creation is linked as the org's first co-manager (not another of the account's personas)" do
      account = Fake.fake_account!()
      chosen = Fake.fake_user!(account)
      other = Fake.fake_user!(account)
      org = Fake.fake_user!(account)

      SharedUsers.init_shared_user(org, %{}, shared_user_creator: chosen)

      usernames =
        SharedUsers.list_linked_users(org) |> Enum.map(&e(&1, :character, :username, nil))

      assert chosen.character.username in usernames
      refute other.character.username in usernames
    end
  end
end
