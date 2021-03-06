defmodule Bonfire.Me.Web.LiveHandlers.Feeds do

  alias Bonfire.Common.Utils
  import Utils
  import Phoenix.LiveView

  def handle_params(%{"after" => cursor_after} = _attrs, _, %{assigns: %{feed_id: feed_id}} = socket) do # if a feed_id has been assigned in the view, load that
    Bonfire.Me.Social.FeedActivities.feed(feed_id, Utils.e(socket.assigns, :current_user, nil), cursor_after) |> live_more(socket, false)
  end

  def handle_params(%{"after" => cursor_after} = _attrs, _, %{assigns: %{current_user: current_user}} = socket) do # if there's no feed_id but we have a user, load "My Feed"
    Bonfire.Me.Social.FeedActivities.my_feed(current_user, cursor_after) |> live_more(socket, false)
  end

  def handle_event("feed_load_more", %{"after" => cursor_after} = _attrs, %{assigns: %{feed_id: feed_id}} = socket) do # if a feed_id has been assigned in the view, load that
    Bonfire.Me.Social.FeedActivities.feed(feed_id, Utils.e(socket.assigns, :current_user, nil), cursor_after) |> live_more(socket)
  end

  def handle_event("feed_load_more", %{"after" => cursor_after} = _attrs, %{assigns: %{current_user: current_user}} = socket) do # if there's no feed_id but we have a user, load "My Feed"
    Bonfire.Me.Social.FeedActivities.my_feed(current_user, cursor_after) |> live_more(socket)
  end

  def live_more(%{} = feed, socket, infinite_scroll \\ true) do
    # IO.inspect(feed_pagination: feed)

    feed = if infinite_scroll, do: e(socket.assigns, :feed, []) ++ e(feed, :entries, []),
           else: e(feed, :entries, [])

    {:noreply,
      socket
      |> Phoenix.LiveView.assign(
        feed: feed,
        page_info: e(feed, :metadata, [])
      )}
  end

  def handle_info(%Bonfire.Data.Social.FeedPublish{}=fp, socket) do
    # IO.inspect(pubsub_received: fp)

    {:noreply,
        Phoenix.LiveView.assign(socket,
          feed: [fp] ++ Map.get(socket.assigns, :feed, [])
      )}
  end

end
