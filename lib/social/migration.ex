defmodule Bonfire.Me.Social.Migration do
  use Ecto.Migration
  import Pointers.Migration

  defp mms(:up) do
    quote do
      require Bonfire.Data.Social.Character.Migration
      require Bonfire.Data.Social.Circle.Migration
      require Bonfire.Data.Social.Encircle.Migration
      require Bonfire.Data.Social.Follow.Migration
      require Bonfire.Data.Social.FollowCount.Migration
      require Bonfire.Data.Social.Like.Migration
      require Bonfire.Data.Social.LikeCount.Migration
      require Bonfire.Data.Social.Profile.Migration
      Bonfire.Data.Social.Profile.Migration.migrate_profile()
      Bonfire.Data.Social.Character.Migration.migrate_character()
      Bonfire.Data.Social.Circle.Migration.migrate_circle()
      Bonfire.Data.Social.Encircle.Migration.migrate_encircle()
      Bonfire.Data.Social.Follow.Migration.migrate_follow()
      Bonfire.Data.Social.FollowCount.Migration.migrate_follow_count()
      Bonfire.Data.Social.Like.Migration.migrate_like()
      Bonfire.Data.Social.LikeCount.Migration.migrate_like_count()
    end
  end

  defp mms(:down) do
    quote do
      require Bonfire.Data.Social.Character.Migration
      require Bonfire.Data.Social.Circle.Migration
      require Bonfire.Data.Social.Encircle.Migration
      require Bonfire.Data.Social.Follow.Migration
      require Bonfire.Data.Social.FollowCount.Migration
      require Bonfire.Data.Social.Like.Migration
      require Bonfire.Data.Social.LikeCount.Migration
      require Bonfire.Data.Social.Profile.Migration
      Bonfire.Data.Social.Profile.Migration.migrate_profile()
      Bonfire.Data.Social.LikeCount.Migration.migrate_like_count()
      Bonfire.Data.Social.Like.Migration.migrate_like()
      Bonfire.Data.Social.FollowCount.Migration.migrate_follow_count()
      Bonfire.Data.Social.Follow.Migration.migrate_follow()
      Bonfire.Data.Social.Encircle.Migration.migrate_encircle()
      Bonfire.Data.Social.Circle.Migration.migrate_circle()
      Bonfire.Data.Social.Character.Migration.migrate_character()
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
