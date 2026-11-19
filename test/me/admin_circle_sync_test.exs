defmodule Bonfire.Me.AdminCircleSyncTest do
  @moduledoc "Shared profiles are never in the admin or mod circles, because their caretaker accounts would get those circles' grants when acting as them. The last member of the admin circle cannot stop being an admin."
  use Bonfire.Me.DataCase, async: true
  @moduletag :backend

  import Ecto.Query
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Users
  alias Bonfire.Me.SharedUsers
  alias Bonfire.Boundaries.Circles
  alias Bonfire.Boundaries.Scaffold.Instance
  alias Bonfire.Data.AccessControl.Encircle

  # reads the encircle rows directly, so no circle cache can hide a stale row
  defp in_circle?(user, circle_id) do
    repo().exists?(
      from(e in Encircle, where: e.subject_id == ^id(user) and e.circle_id == ^circle_id)
    )
  end

  defp admin?(user), do: in_circle?(user, Instance.admin_circle())
  defp mod?(user), do: in_circle?(user, Instance.mod_circle())

  defp account_admin?(account),
    do: Accounts.is_admin?(repo().preload(account, :instance_admin, force: true)) == true

  defp shared?(user),
    do: Bonfire.Common.URIs.shared_user?(repo().preload(user, :shared_user, force: true))

  defp make_shared(user, account),
    do: SharedUsers.init_shared_user(user, %{}, current_account: account)

  defp new_admin! do
    assert {:ok, account} = Accounts.signup(signup_form())
    assert {:ok, user} = Users.create(create_user_form(), account)
    assert {:ok, user} = Users.make_admin(user, skip_boundary_check: true)
    {account, user}
  end

  test "make_admin refuses a shared profile" do
    assert {:ok, account} = Accounts.signup(signup_form())
    assert {:ok, team} = Users.create(create_user_form(), account)
    make_shared(team, account)

    assert {:error, _} = Users.make_admin(team, skip_boundary_check: true)
    refute admin?(team)
  end

  test "becoming a shared user removes the profile from the admin and mod circles" do
    # another admin, so `user` is not the last one
    new_admin!()
    {account, user} = new_admin!()

    assert {:ok, _} =
             Circles.add_to_circles(user, Instance.mod_circle(), skip_boundary_check: true)

    # prove the positive first
    assert admin?(user)
    assert mod?(user)

    make_shared(user, account)

    refute admin?(user)
    refute mod?(user)
  end

  # admin powers belong to the account, while each profile is added to the admin circle on its own
  test "revoking one profile keeps its account an admin while another of its profiles is still in the admin circle" do
    # another admin, so neither profile below is the last one
    new_admin!()
    {account, first} = new_admin!()
    assert {:ok, second} = Users.create(create_user_form(), account)
    assert {:ok, _} = Users.make_admin(second, skip_boundary_check: true)

    assert {:ok, _} = Users.revoke_admin(first, skip_boundary_check: true)

    refute admin?(first)
    assert admin?(second)
    assert account_admin?(account)

    # the last of its profiles to leave the circle takes the account's admin powers with it
    assert {:ok, _} = Users.revoke_admin(second, skip_boundary_check: true)

    refute admin?(second)
    refute account_admin?(account)
  end

  describe "the last admin" do
    test "can be revoked while another admin remains" do
      new_admin!()
      {_account, user} = new_admin!()

      assert {:ok, _} = Users.revoke_admin(user, skip_boundary_check: true)
      refute admin?(user)
    end

    test "cannot be revoked" do
      {_account, user} = new_admin!()

      assert {:error, _} = Users.revoke_admin(user, skip_boundary_check: true)
      assert admin?(user)
    end

    test "cannot become a shared user" do
      {account, user} = new_admin!()

      assert {:error, _} = make_shared(user, account)
      assert admin?(user)
      refute shared?(user)
    end

    test "cannot be deleted" do
      {_account, user} = new_admin!()

      assert {:error, _} = Users.enqueue_delete(user)
      assert admin?(user)
    end

    test "cannot have their account deleted" do
      {account, user} = new_admin!()

      assert {:error, _} = Accounts.enqueue_delete(account)
      assert admin?(user)
    end

    test "cannot have their account deleted by queueing only the account, as the delete account action does" do
      {account, user} = new_admin!()

      assert {:error, _} = Bonfire.Me.DeleteWorker.enqueue_delete(account)
      assert admin?(user)
    end

    test "can be deleted while another admin remains" do
      new_admin!()
      {_account, user} = new_admin!()

      assert {:ok, _} = Users.enqueue_delete(user)
    end
  end
end
