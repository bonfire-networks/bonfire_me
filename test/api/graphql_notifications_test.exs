if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.Me.API.GraphQL.NotificationsTest do
    use Bonfire.Me.DataCase, async: false

    import Bonfire.Me.Fake

    alias Bonfire.API.GraphQL.Schema

    @moduletag :graphql

    setup do
      account = fake_account!()
      me = fake_user!(account)
      other = fake_user!(fake_account!())
      follower = fake_user!(fake_account!())

      {:ok, me: me, other: other, follower: follower}
    end

    test "me.notifications applies feed filters", %{me: me, other: other, follower: follower} do
      post = publish_post!(me, "GraphQL notification filter target")

      assert {:ok, _like} = Bonfire.Social.Likes.like(other, post)
      assert {:ok, _follow} = Bonfire.Social.Graph.Follows.follow(follower, me)

      {:ok, result} =
        Absinthe.run(
          ~S|query {
            me {
              notifications(first: 10, filter: {activity_types: ["like"]}) {
                edges {
                  node {
                    id
                    objectId
                    verb { verb }
                  }
                }
              }
            }
          }|,
          Schema,
          context: Schema.context(%{current_user: me})
        )

      refute result[:errors]

      nodes =
        result
        |> get_in([:data, "me", "notifications", "edges"])
        |> List.wrap()
        |> Enum.map(&get_in(&1, ["node"]))

      assert Enum.any?(nodes, &(&1["objectId"] == post.id))
      assert Enum.all?(nodes, &(get_in(&1, ["verb", "verb"]) in ["Like", "like"]))
    end

    test "me.notifications supports notification type filters for mentions", %{
      me: me,
      other: other,
      follower: follower
    } do
      post = publish_post!(me, "GraphQL notification type filter target")

      assert {:ok, _like} = Bonfire.Social.Likes.like(follower, post)

      mention =
        publish_post!(
          other,
          "hey @#{me.character.username} this should be a mention notification",
          boundary: "mentions"
        )

      {:ok, result} =
        Absinthe.run(
          ~S|query {
            me {
              notifications(first: 10, filter: {notificationTypes: ["mention"]}) {
                edges {
                  node {
                    id
                    objectId
                    verb { verb }
                  }
                }
              }
            }
          }|,
          Schema,
          context: Schema.context(%{current_user: me})
        )

      refute result[:errors]

      nodes =
        result
        |> get_in([:data, "me", "notifications", "edges"])
        |> List.wrap()
        |> Enum.map(&get_in(&1, ["node"]))

      assert Enum.any?(nodes, &(&1["objectId"] == mention.id))
      refute Enum.any?(nodes, &(&1["objectId"] == post.id))

      assert Enum.all?(
               nodes,
               &(get_in(&1, ["verb", "verb"]) in ["Create", "create", "Reply", "reply"])
             )
    end

    test "me.notifications rejects unsupported notification type filters", %{me: me} do
      {:ok, result} =
        Absinthe.run(
          ~S|query {
            me {
              notifications(first: 10, filter: {notificationTypes: ["not_a_notification"]}) {
                edges { node { id } }
              }
            }
          }|,
          Schema,
          context: Schema.context(%{current_user: me})
        )

      assert result[:errors]
      assert get_in(result, [:data, "me", "notifications"]) == nil
    end

    defp publish_post!(user, body, opts \\ []) do
      assert {:ok, post} =
               Bonfire.Posts.publish(
                 post_attrs: %{post_content: %{html_body: "<p>#{body}</p>"}},
                 current_user: user,
                 boundary: Keyword.get(opts, :boundary, "public")
               )

      post
    end
  end
end
