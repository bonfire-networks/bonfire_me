defmodule Bonfire.Me.FollowsTest do
  use Bonfire.DataCase

  alias Bonfire.Me.Social.Follows
  alias Bonfire.Me.Fake

  test "follow works" do

    me = Fake.fake_user!()
    followed = Fake.fake_user!()
    assert {:ok, follow} = Follows.follow(me, followed)
    # IO.inspect(follow)
    assert follow.follower_id == me.id
    assert follow.followed_id == followed.id
  end

  test "can fetch follows" do
    me = Fake.fake_user!()
    followed = Fake.fake_user!()
    assert {:ok, follow} = Follows.follow(me, followed)

    assert {:ok, fetched_follow} = Follows.get(me, followed)

    assert fetched_follow == follow.id
  end

  test "can check if following someone" do
    me = Fake.fake_user!()
    followed = Fake.fake_user!()
    assert {:ok, follow} = Follows.follow(me, followed)

    assert true == Follows.following?(me, followed)
  end

  test "can unfollow someone" do
    me = Fake.fake_user!()
    followed = Fake.fake_user!()
    assert {:ok, follow} = Follows.follow(me, followed)

    Follows.unfollow(me, followed)
    assert false == Follows.following?(me, followed)
  end
end
