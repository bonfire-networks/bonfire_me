defmodule Bonfire.Me.PostsTest do
  use Bonfire.DataCase

  alias Bonfire.Social.Posts
  alias Bonfire.Me.Fake

  test "creation works" do
    attrs = %{post_content: %{summary: "summary", name: "name", html_body: "<p>epic html message</p>"}}
    account = Fake.fake_account!()
    user = Fake.fake_user!(account)
    assert {:ok, activty} = Posts.publish(user, attrs)
    assert activity.post.post_content.html_body == "<p>epic html message</p>"
    assert activity.post.post_content.name == "name"
    assert activity.post.post_content.summary == "summary"
    assert activity.post.created.creator_id == user.id
  end

  test "fetching by creator" do
    attrs_1 = %{post_content: %{summary: "summary", name: "name", html_body: "<p>epic html message 1</p>"}}
    attrs_2 = %{post_content: %{summary: "summary", name: "name", html_body: "<p>epic html message 2</p>"}}
    attrs_3 = %{post_content: %{summary: "summary", name: "name", html_body: "<p>epic html message 3</p>"}}
    account = Fake.fake_account!()
    user = Fake.fake_user!(account)
    assert {:ok, _} = Posts.publish(user, attrs_1)
    assert {:ok, _} = Posts.publish(user, attrs_2)
    assert {:ok, _} = Posts.publish(user, attrs_3)
    posts = Posts.by_user(user.id)
    assert length(posts) == 3
  end
end
