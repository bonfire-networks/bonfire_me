defmodule Bonfire.Me.Web.InstanceLive do
  use Bonfire.Web, :live_view
  alias Bonfire.Fake
  alias Bonfire.Common.Web.LivePlugs
  alias Bonfire.Me.Identity.Users
  alias Bonfire.Me.Web.{CreateUserLive}

  def mount(params, session, socket) do
    LivePlugs.live_plug params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      LivePlugs.LoadCurrentAccountUsers,
      LivePlugs.StaticChanged,
      LivePlugs.Csrf,
      &mounted/3,
    ]
  end

  defp mounted(params, session, socket) do

    feed = Bonfire.Me.Social.Feeds.instance_feed_id() |> Bonfire.Me.Social.FeedActivities.feed()

    title = "Feed of all activities by users on this instance"
    {:ok, socket
    |> assign(
      page_title: "Instance Feed",
      feed_title: title,
      feed: e(feed, :entries, []),
      page_info: e(feed, :metadata, [])
      )}
  end


  # def handle_params(%{"tab" => tab} = _params, _url, socket) do
  #   {:noreply,
  #    assign(socket,
  #      selected_tab: tab
  #    )}
  # end

  # def handle_params(%{} = _params, _url, socket) do
  #   {:noreply,
  #    assign(socket,
  #      current_user: Fake.user_live()
  #    )}
  # end

  def handle_event("load-more", attrs, socket), do: Bonfire.Me.Social.Feeds.instance_feed_id() |> Bonfire.Me.Social.FeedActivities.live_more(attrs, socket)

  def handle_event("post", attrs, socket), do: Bonfire.Me.Social.Posts.live_post(attrs, socket)

end
