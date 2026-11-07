defmodule Bonfire.Me.Users.UndiscoverableToggleTest do
  @moduledoc """
  Turning "I do not want my profile to be easily discoverable" on or off after signup changes who finds the profile in user listings, the same as choosing it at signup does. The setting is saved with `Settings.put/3`, as the settings toggle does.
  """
  use Bonfire.Me.DataCase, async: true
  @moduletag :backend

  alias Bonfire.Me.Users
  alias Bonfire.Common.Settings
  import Bonfire.Me.Fake

  defp listed?(user, viewer_opts),
    do: user.id in Enum.map(Users.list(viewer_opts), & &1.id)

  test "a user who turns undiscoverable on is no longer listed for guests" do
    user = fake_user!()

    # the positive first
    assert listed?(user, current_user: nil)

    Settings.put([Users, :undiscoverable], true, current_user: user)

    refute listed?(user, current_user: nil)
  end

  test "a user who turns undiscoverable off again is listed for guests" do
    user = fake_user!(%{}, %{}, undiscoverable: true)
    refute listed?(user, current_user: nil)

    Settings.put([Users, :undiscoverable], false, current_user: user)

    assert listed?(user, current_user: nil)
  end
end
