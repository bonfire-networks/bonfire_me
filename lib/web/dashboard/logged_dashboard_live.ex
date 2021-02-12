defmodule Bonfire.Me.Web.LoggedDashboardLive do
    use Bonfire.Web, :live_view
    alias Bonfire.Me.Fake
    alias Bonfire.Common.Web.LivePlugs
    alias Bonfire.Me.Users
    alias Bonfire.Me.Web.CreateUserLive
    alias Bonfire.UI.Social.FeedLive

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
      feed = Bonfire.Me.Social.FeedActivities.my_feed(socket.assigns.current_user)

      title = "My Feed"

      {:ok, socket
      |> assign(
        page: "dashboard",
        page_title: "Bonfire Dashboard",
        feed_title: title,
        feed: e(feed, :entries, []),
        page_info: e(feed, :metadata, []),
        go: ""
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

  def handle_event("load-more", attrs, socket), do: Bonfire.Me.Social.FeedActivities.my_live_more(attrs, socket)
# undead(socket, fn -> :foo + 1 end)

  def handle_event("post", attrs, socket), do: Bonfire.Me.Social.Posts.live_post(attrs, socket)

  def handle_info(%Bonfire.Data.Social.FeedPublish{}=fp, socket), do: Bonfire.Me.Social.FeedActivities.live_add(fp, socket)

end
