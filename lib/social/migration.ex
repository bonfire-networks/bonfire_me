defmodule Bonfire.Me.Social.Migration do
  use Ecto.Migration
  import Pointers.Migration

  defp mms(:up) do
    quote do
      require Bonfire.Data.Social.Article.Migration
      require Bonfire.Data.Social.Block.Migration
      require Bonfire.Data.Social.Bookmark.Migration
      require Bonfire.Data.Social.Circle.Migration
      require Bonfire.Data.Social.Encircle.Migration
      require Bonfire.Data.Social.Follow.Migration
      require Bonfire.Data.Social.FollowCount.Migration
      require Bonfire.Data.Social.Like.Migration
      require Bonfire.Data.Social.LikeCount.Migration
      require Bonfire.Data.Social.Mention.Migration
      require Bonfire.Data.Social.Named.Migration
      require Bonfire.Data.Social.Post.Migration
      require Bonfire.Data.Social.PostContent.Migration
      require Bonfire.Data.Social.Profile.Migration
      require Bonfire.Data.Social.Created.Migration
      require Bonfire.Data.Social.Activity.Migration
      require Bonfire.Data.Social.Feed.Migration
      require Bonfire.Data.Social.FeedPublish.Migration

      Bonfire.Data.Social.Article.Migration.migrate_article()
      Bonfire.Data.Social.Block.Migration.migrate_block()
      Bonfire.Data.Social.Bookmark.Migration.migrate_bookmark()
      Bonfire.Data.Social.Circle.Migration.migrate_circle()
      Bonfire.Data.Social.Encircle.Migration.migrate_encircle()
      Bonfire.Data.Social.Follow.Migration.migrate_follow()
      Bonfire.Data.Social.FollowCount.Migration.migrate_follow_count()
      Bonfire.Data.Social.Like.Migration.migrate_like()
      Bonfire.Data.Social.LikeCount.Migration.migrate_like_count()
      Bonfire.Data.Social.Mention.Migration.migrate_mention()
      Bonfire.Data.Social.Named.Migration.migrate_named()
      Bonfire.Data.Social.Post.Migration.migrate_post()
      Bonfire.Data.Social.PostContent.Migration.migrate_post_content()
      Bonfire.Data.Social.Profile.Migration.migrate_profile()
      Bonfire.Data.Social.Created.Migration.migrate_created()
      Bonfire.Data.Social.Activity.Migration.migrate_activity()
      Bonfire.Data.Social.Feed.Migration.migrate_feed()
      Bonfire.Data.Social.FeedPublish.Migration.migrate_feed_publish()
    end
  end

  defp mms(:down) do
    quote do
      require Bonfire.Data.Social.Article.Migration
      require Bonfire.Data.Social.Block.Migration
      require Bonfire.Data.Social.Bookmark.Migration
      require Bonfire.Data.Social.Circle.Migration
      require Bonfire.Data.Social.Encircle.Migration
      require Bonfire.Data.Social.Follow.Migration
      require Bonfire.Data.Social.FollowCount.Migration
      require Bonfire.Data.Social.Like.Migration
      require Bonfire.Data.Social.LikeCount.Migration
      require Bonfire.Data.Social.Mention.Migration
      require Bonfire.Data.Social.Named.Migration
      require Bonfire.Data.Social.Post.Migration
      require Bonfire.Data.Social.PostContent.Migration
      require Bonfire.Data.Social.Profile.Migration
      require Bonfire.Data.Social.Created.Migration
      require Bonfire.Data.Social.Activity.Migration
      require Bonfire.Data.Social.Feed.Migration
      require Bonfire.Data.Social.FeedPublish.Migration

      Bonfire.Data.Social.Profile.Migration.migrate_profile()
      Bonfire.Data.Social.PostContent.Migration.migrate_post_content()
      Bonfire.Data.Social.Post.Migration.migrate_post()
      Bonfire.Data.Social.Named.Migration.migrate_named()
      Bonfire.Data.Social.Mention.Migration.migrate_mention()
      Bonfire.Data.Social.LikeCount.Migration.migrate_like_count()
      Bonfire.Data.Social.Like.Migration.migrate_like()
      Bonfire.Data.Social.FollowCount.Migration.migrate_follow_count()
      Bonfire.Data.Social.Follow.Migration.migrate_follow()
      Bonfire.Data.Social.Encircle.Migration.migrate_encircle()
      Bonfire.Data.Social.Circle.Migration.migrate_circle()
      Bonfire.Data.Social.Bookmark.Migration.migrate_bookmark()
      Bonfire.Data.Social.Block.Migration.migrate_block()
      Bonfire.Data.Social.Article.Migration.migrate_article()
      Bonfire.Data.Social.Created.Migration.migrate_created()
      Bonfire.Data.Social.Activity.Migration.migrate_activity()
      Bonfire.Data.Social.Feed.Migration.migrate_feed()
      Bonfire.Data.Social.FeedPublish.Migration.migrate_feed_publish()
    end
  end

  defmacro migrate_me_social() do
    quote do
      if Ecto.Migration.direction() == :up,
        do: unquote(mms(:up)),
        else: unquote(mms(:down))
    end
  end
  defmacro migrate_me_social(dir), do: mms(dir)

end
