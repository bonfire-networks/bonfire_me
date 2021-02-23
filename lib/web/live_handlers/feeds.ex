defmodule Bonfire.Me.Web.LiveHandlers.Feeds do

  alias Bonfire.Common.Utils
  import Utils
  import Phoenix.LiveView

  def handle_event("feed_load_more", %{"after" => cursor_after} = _attrs, %{assigns: %{feed_id: feed_id}} = socket) do # if a feed_id has been assigned in the view, load that
    Bonfire.Me.Social.FeedActivities.feed(feed_id, Utils.e(socket.assigns, :current_user, nil), cursor_after) |> live_more(socket)
  end

  def handle_event("feed_load_more", %{"after" => cursor_after} = _attrs, %{assigns: %{current_user: current_user}} = socket) do # if there's no feed_id but we have a user, load "My Feed"
    Bonfire.Me.Social.FeedActivities.my_feed(current_user, cursor_after) |> live_more(socket)
  end

  def live_more(%{} = feed, socket) do
    # IO.inspect(feed_pagination: feed)
    {:noreply,
      socket
      |> Phoenix.LiveView.assign(
        feed: e(socket.assigns, :feed, []) ++ Utils.e(feed, :entries, []),
        page_info: Utils.e(feed, :metadata, [])
      )}
  end

  def handle_info(%Bonfire.Data.Social.FeedPublish{}=fp, socket) do
    IO.inspect(pubsub_received: fp)

    {:noreply,
        Phoenix.LiveView.assign(socket,
          feed: [fp] ++ Map.get(socket.assigns, :feed, [])
      )}
  end

end
