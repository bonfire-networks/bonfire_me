defmodule Bonfire.Social.Boundaries.InstanceWideGhostActorTest do
  use Bonfire.Me.ConnCase
  # import Bonfire.Boundaries.Debug
  alias ActivityPub.Config

  test "instance-wide ghosted local user cannot switch to that identity" do
    bob = fake_account!()
    bob_user = fake_user!(bob)
    Bonfire.Boundaries.Blocks.block(bob_user, :ghost, :instance_wide)

    conn = conn(account: bob)
    conn = get(conn, "/switch-user/#{bob_user.character.username}")
    assert redirected_to(conn) == "/switch-user"
    conn = get(recycle(conn), "/switch-user")
    doc = floki_response(conn)
    assert [err] = find_flash(doc)
    assert_flash_kind(err, :error)
  end

end
