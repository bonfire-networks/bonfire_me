defmodule Bonfire.Me.InstanceModeratorsTest do
  @moduledoc """
  The people who moderate the instance: the members of the mod circle. `make_admin` adds the admin circle only, so an admin is not a moderator, but an instance with no moderator (every one, until someone is added) falls back to its admins, so that what is sent to its moderators reaches someone. `list_admins_and_moderators/1` is for the callers that want all of them.
  """
  use Bonfire.Me.DataCase, async: true
  @moduletag :backend

  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Fake
  alias Bonfire.Me.SharedUsers
  alias Bonfire.Me.Users

  defp user_ids(users), do: Enum.map(users, & &1.id)

  defp admin! do
    {:ok, admin} = Users.make_admin(Fake.fake_user!())
    admin
  end

  test "with no moderator, the moderators are the admins" do
    admin = admin!()

    assert admin.id in user_ids(Users.list_moderators())
  end

  test "the moderators are the members of the mod circle, and not the admins" do
    admin = admin!()
    moderator = Fake.instance_moderator!(Fake.fake_user!())

    moderators = user_ids(Users.list_moderators())

    assert moderator.id in moderators
    refute admin.id in moderators
  end

  test "make_moderator puts a user in the moderators, and revoke_moderator takes them out" do
    admin = admin!()
    user = Fake.fake_user!()

    assert {:ok, _} = Users.make_moderator(user)
    assert user.id in user_ids(Users.list_moderators())
    refute admin.id in user_ids(Users.list_moderators())

    assert {:ok, _} = Users.revoke_moderator(user)
    refute user.id in user_ids(Users.list_moderators())
    # no moderator left: the admins stand in again
    assert admin.id in user_ids(Users.list_moderators())
  end

  test "make_moderator refuses a shared profile" do
    assert {:ok, account} = Accounts.signup(signup_form())
    assert {:ok, team} = Users.create(create_user_form(), account)
    SharedUsers.init_shared_user(team, %{}, current_account: account)

    assert {:error, _} = Users.make_moderator(team)
    refute team.id in user_ids(Users.list_admins_and_moderators())
  end

  test "make_admin makes a moderator too when asked to, and not otherwise" do
    plain = admin!()
    assert {:ok, also_moderator} = Users.make_admin(Fake.fake_user!(), moderator: true)
    Fake.instance_moderator!(Fake.fake_user!())

    moderators = user_ids(Users.list_moderators())
    assert also_moderator.id in moderators
    refute plain.id in moderators
  end

  describe "list_instance_wide/2: who holds a verb for the whole instance" do
    alias Bonfire.Boundaries.Circles
    alias Bonfire.Boundaries.Grants
    alias Bonfire.Boundaries.Scaffold.Instance

    defp circle_with!(members, name) do
      assert {:ok, circle} = Circles.create(Fake.fake_user!(), name)
      for member <- members, do: assert({:ok, _} = Circles.add_to_circles(member, circle))
      circle
    end

    defp grant_instance_wide!(circle, verb, value),
      do: Grants.grant(circle.id, Instance.instance_acl(), verb, value, skip_boundary_check: true)

    test "lists the admins and the members of the mod circle, who hold it by default" do
      admin = admin!()
      moderator = Fake.instance_moderator!(Fake.fake_user!())
      someone = Fake.fake_user!()

      holders = user_ids(Users.list_instance_wide(:mediate))

      assert admin.id in holders
      assert moderator.id in holders
      refute someone.id in holders
    end

    test "lists the members of any circle the instance gave it to, and nobody else" do
      member = Fake.fake_user!()
      outsider = Fake.fake_user!()
      circle = circle_with!([member], "reviewers")
      grant_instance_wide!(circle, :mediate, true)

      holders = user_ids(Users.list_instance_wide(:mediate))

      assert member.id in holders
      refute outsider.id in holders
    end

    test "leaves out whoever is denied it, though they hold it through another circle" do
      member = Fake.instance_moderator!(Fake.fake_user!())
      denied = circle_with!([member], "not reviewers")
      grant_instance_wide!(denied, :mediate, false)

      refute member.id in user_ids(Users.list_instance_wide(:mediate))
    end

    test "an admin holds it whatever the grants say" do
      admin = admin!()
      denied = circle_with!([admin], "not reviewers")
      grant_instance_wide!(denied, :mediate, false)

      assert admin.id in user_ids(Users.list_instance_wide(:mediate))
    end
  end

  test "the admins and the moderators are both listed, an admin who is also a moderator once" do
    admin = admin!()
    moderator = Fake.instance_moderator!(Fake.fake_user!())
    both = Fake.instance_moderator!(admin!())

    all = user_ids(Users.list_admins_and_moderators())

    assert admin.id in all
    assert moderator.id in all
    assert Enum.count(all, &(&1 == both.id)) == 1
  end
end
