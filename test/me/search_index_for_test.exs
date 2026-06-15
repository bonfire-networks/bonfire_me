defmodule Bonfire.Me.Users.SearchIndexForTest do
  use Bonfire.Me.DataCase, async: true

  alias Bonfire.Me.Users
  import Bonfire.Me.Fake

  test "a discoverable user is indexed in the :public index" do
    user = fake_user!()
    assert Users.search_index_for(user) == :public
  end

  test "an undiscoverable user is indexed in the :closed index" do
    # set the per-user discoverability *setting* that search_index_for reads (the boundaries-only
    # `undiscoverable:` fake_user! opt does not persist this setting)
    user =
      current_user(
        Bonfire.Common.Settings.put([Bonfire.Me.Users, :undiscoverable], true,
          current_user: fake_user!()
        )
      )

    assert Users.search_index_for(user) == :closed
  end
end
