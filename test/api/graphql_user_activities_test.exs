if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.Me.API.GraphQL.UserActivitiesTest do
    use Bonfire.Me.DataCase, async: false

    import Bonfire.Me.Fake

    alias Bonfire.API.GraphQL.Schema

    @moduletag :graphql

    @user_activities """
    query {
      me {
        user {
          id
          user_activities(paginate: {limit: 20}) {
            id
            object {
              __typename
              ... on Post {
                id
                post_content {
                  raw_body
                  html_body
                }
              }
            }
            object_post_content {
              raw_body
              html_body
            }
          }
        }
      }
    }
    """

    setup do
      account = fake_account!()
      me = fake_user!(account)
      other = fake_user!(fake_account!())

      {:ok, me: me, other: other}
    end

    test "me.user.user_activities returns the user's posts with object content", %{
      me: me,
      other: other
    } do
      my_post = publish_post!(me, "GraphQL user activities owner post")
      other_post = publish_post!(other, "GraphQL user activities other post")

      {:ok, result} =
        Absinthe.run(@user_activities, Schema, context: Schema.context(%{current_user: me}))

      refute result[:errors]

      activities =
        result
        |> get_in([:data, "me", "user", "user_activities"])
        |> List.wrap()

      assert Enum.any?(activities, &activity_contains_post?(&1, my_post.id, "owner post"))
      refute Enum.any?(activities, &activity_contains_post?(&1, other_post.id, "other post"))
    end

    defp publish_post!(user, body) do
      assert {:ok, post} =
               Bonfire.Posts.publish(
                 post_attrs: %{post_content: %{html_body: "<p>#{body}</p>"}},
                 current_user: user,
                 boundary: "public"
               )

      post
    end

    defp activity_contains_post?(activity, post_id, body) do
      raw_body =
        get_in(activity, ["object", "post_content", "raw_body"]) ||
          get_in(activity, ["object_post_content", "raw_body"]) ||
          ""

      activity["id"] == post_id and
        raw_body =~ body
    end
  end
end
