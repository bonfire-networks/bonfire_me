defmodule Bonfire.Me.InstanceSettingsAdminCheckTest do
  @moduledoc "Only an instance admin changes instance settings. The check reads the admin flag on the acting user's account: an admin whose flag wasn't loaded with their account is an error in tests (so the caller can preload it), never a silent refusal. Settings in other scopes don't look at the flag."
  # instance-scope settings are mirrored into the global Application env, which the sandbox doesn't roll back
  use Bonfire.Me.DataCase, async: false
  @moduletag :backend

  alias Bonfire.Common.Settings
  alias Bonfire.Data.Identity.Account
  alias Bonfire.Me.Fake

  @key [__MODULE__, :probe]

  defp clear_instance_setting do
    if Bonfire.Common.Config.get(@key, nil) != nil do
      [otp_app | keys] = Bonfire.Common.Config.keys_tree(@key)
      Bonfire.Common.Config.delete(keys, otp_app)
    end
  end

  # the user with their account loaded, as `current_account(opts)` finds it on them, with or without its `instance_admin`
  defp with_account(user, account, preload_flag?) do
    account = repo().get!(Account, account.id)

    Map.put(
      user,
      :account,
      if(preload_flag?, do: repo().preload(account, :instance_admin), else: account)
    )
  end

  setup do
    clear_instance_setting()
    on_exit(&clear_instance_setting/0)

    admin_account = Fake.fake_account!()

    {:ok, admin} =
      Bonfire.Me.Users.make_admin(Fake.fake_user!(admin_account), skip_boundary_check: true)

    user_account = Fake.fake_account!()
    user = Fake.fake_user!(user_account)

    unloaded_admin = with_account(admin, admin_account, false)
    assert %Ecto.Association.NotLoaded{} = unloaded_admin.account.instance_admin

    %{
      loaded_admin: with_account(admin, admin_account, true),
      unloaded_admin: unloaded_admin,
      non_admin: with_account(user, user_account, true),
      unloaded_non_admin: with_account(user, user_account, false)
    }
  end

  test "an instance admin changes an instance setting", %{
    loaded_admin: loaded_admin,
    unloaded_admin: unloaded_admin,
    non_admin: non_admin
  } do
    assert {:ok, _} = Settings.put(@key, true, scope: :instance, current_user: loaded_admin)
    assert Settings.get(@key, nil, :instance) == true, "control: an admin changes it"

    assert_raise RuntimeError, ~r/preload instance_admin/, fn ->
      Settings.put(@key, false, scope: :instance, current_user: unloaded_admin)
    end

    assert_raise Bonfire.Fail, fn ->
      Settings.put(@key, false, scope: :instance, current_user: non_admin)
    end

    assert Settings.get(@key, nil, :instance) == true
  end

  test "a setting of the user's own doesn't look at the admin flag", %{
    unloaded_non_admin: unloaded_non_admin
  } do
    assert {:ok, _} = Settings.put(@key, true, scope: :user, current_user: unloaded_non_admin)
  end
end
