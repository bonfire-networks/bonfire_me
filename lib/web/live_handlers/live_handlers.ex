defmodule Bonfire.Me.Web.LiveHandlers do

  # start handler pattern matching

  alias Bonfire.Me.Web.LiveHandlers.{Likes, Posts, Feeds, Follows, Profiles}

  @like_actions ["like"]
  @post_actions ["post", "post_reply", "post_load_replies"]
  @feed_actions ["feed_load_more"]
  @follow_actions ["follow", "unfollow"]
  @profile_actions ["profile_save"]

  # Likes
  defp do_handle_event(action, attrs, socket) when action in @like_actions or binary_part(action, 0, 4) == "like", do: Likes.handle_event(action, attrs, socket)

  # Posts
  defp do_handle_event(action, attrs, socket) when action in @post_actions or binary_part(action, 0, 4) == "post", do: Posts.handle_event(action, attrs, socket)

  # Feeds
  defp do_handle_event(action, attrs, socket) when action in @feed_actions or binary_part(action, 0, 4) == "feed", do: Feeds.handle_event(action, attrs, socket)
  defp do_handle_info(%Bonfire.Data.Social.FeedPublish{} = info, socket), do: Feeds.handle_info(info, socket)

  # Follows
  defp do_handle_event(action, attrs, socket) when action in @follow_actions or binary_part(action, 0, 6) == "follow", do: Follows.handle_event(action, attrs, socket)

  # Profiles
  defp do_handle_event(action, attrs, socket) when action in @profile_actions or binary_part(action, 0, 7) == "profile", do: Profiles.handle_event(action, attrs, socket)

  # end of handler pattern matching


  alias Bonfire.Common.Utils
  import Utils

  def handle_event(action, attrs, socket) do
    undead(socket, fn ->
      do_handle_event(action, attrs, socket)
    end)
  end

  def handle_info(info, socket) do
    undead(socket, fn ->
      do_handle_info(info, socket)
    end)
  end

end
