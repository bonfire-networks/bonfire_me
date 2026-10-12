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

  defp shared?(user),
    do: Bonfire.Common.URIs.shared_user?(repo().preload(user, :shared_user, force: true))

  defp make_shared(user, account),
    do: SharedUsers.init_shared_user(user, %{}, current_account: account)

  defp new_admin! do
    assert {:ok, account} = Accounts.signup(signup_form())
    assert {:ok, user} = Users.create(create_user_form(), account)
    assert {:ok, user} = Users.make_admin(user)
    {account, user}
  end

  test "make_admin refuses a shared profile" do
    assert {:ok, account} = Accounts.signup(signup_form())
    assert {:ok, team} = Users.create(create_user_form(), account)
    make_shared(team, account)

    assert {:error, _} = Users.make_admin(team)
    refute admin?(team)
  end

  test "becoming a shared user removes the profile from the admin and mod circles" do
    # another admin, so `user` is not the last one
    new_admin!()
    {account, user} = new_admin!()
    assert {:ok, _} = Circles.add_to_circles(user, Instance.mod_circle())
    # prove the positive first
    assert admin?(user)
    assert mod?(user)

    make_shared(user, account)

    refute admin?(user)
    refute mod?(user)
  end

  describe "the last admin" do
    test "can be revoked while another admin remains" do
      new_admin!()
      {_account, user} = new_admin!()

      assert {:ok, _} = Users.revoke_admin(user)
      refute admin?(user)
    end

    test "cannot be revoked" do
      {_account, user} = new_admin!()

      assert {:error, _} = Users.revoke_admin(user)
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
