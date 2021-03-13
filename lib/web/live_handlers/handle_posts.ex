defmodule Bonfire.Me.Web.LiveHandlers.Posts do

  alias Bonfire.Common.Utils
  import Utils
  import Phoenix.LiveView

  def handle_event("post", params, socket) do
    attrs = params
    |> input_to_atoms()
    # |> IO.inspect

    with {:ok, published} <- Bonfire.Me.Social.Posts.publish(socket.assigns.current_user, attrs) do
      # IO.inspect("published!")
      {:noreply,
        socket
        # Phoenix.LiveView.assign(socket,
        #   feed: [%{published.activity | object_post: published.post, subject_user: socket.assigns.current_user}] ++ Map.get(socket.assigns, :feed, [])
        # )
      }
    end
  end

  def handle_event("post_load_replies", %{"id" => id, "level" => level}, socket) do
    {level, _} = Integer.parse(level)
    replies = Bonfire.Me.Social.Posts.list_replies(id, level + @thread_max_depth)
    replies = replies ++ socket.assigns.replies
    {:noreply,
        assign(socket,
        replies: replies,
        threaded_replies: Bonfire.Me.Social.Posts.arrange_replies_tree(replies) || []
    )}
  end

  def handle_event("post_reply", attrs, socket) do

    attrs = attrs |> input_to_atoms()

    with {:ok, published} <- Bonfire.Me.Social.Posts.reply(socket.assigns.current_user, attrs) do
      replies = [published] ++ socket.assigns.replies # TODO: replace with pubsub
    # IO.inspect(replies, label: "rep:")
      {:noreply,
        assign(socket,
        replies: replies,
        threaded_replies: Bonfire.Me.Social.Posts.arrange_replies_tree(replies) || []
    )}
    end

  end


end
