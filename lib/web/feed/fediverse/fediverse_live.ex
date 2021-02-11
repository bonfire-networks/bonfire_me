defmodule Bonfire.Me.Web.FediverseLive do
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

    feed = Bonfire.Me.Social.Feeds.fediverse_feed_id() |> Bonfire.Me.Social.FeedActivities.feed()

    title = "Feed of activities from around the fediverse"

    {:ok, socket
    |> assign(
      page: "fediverse",
      page_title: "Fediverse Feed",
      feed_title: title,
      feed: [],
      page_info: nil
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

  def handle_event("load-more", attrs, socket), do: Bonfire.Me.Social.Feeds.fediverse_feed_id() |> Bonfire.Me.Social.FeedActivities.live_more(attrs, socket)

  def handle_event("post", attrs, socket), do: Bonfire.Me.Social.Posts.live_post(attrs, socket)

  def handle_info(%Bonfire.Data.Social.FeedPublish{}=fp, socket), do: Bonfire.Me.Social.FeedActivities.live_add(fp, socket)

end
