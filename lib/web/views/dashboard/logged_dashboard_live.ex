defmodule Bonfire.Me.Web.LoggedDashboardLive do
    use Bonfire.Web, :live_view
    alias Bonfire.Me.Fake
    alias Bonfire.Web.LivePlugs
    alias Bonfire.Me.Users
    alias Bonfire.Me.Web.CreateUserLive
    alias Bonfire.UI.Social.FeedLive

    def mount(params, session, socket) do
      LivePlugs.live_plug params, session, socket, [
        LivePlugs.LoadCurrentAccount,
        LivePlugs.LoadCurrentUser,
        LivePlugs.LoadCurrentAccountUsers,
        # LivePlugs.LoadCurrentUserCircles,
        LivePlugs.StaticChanged,
        LivePlugs.Csrf,
        &mounted/3,
      ]
    end

    defp mounted(params, session, socket) do

      feed = Bonfire.Social.FeedActivities.my_feed(socket.assigns.current_user)

      {:ok, socket
      |> assign(
        page: "dashboard",
        smart_input: true,
        has_private_tab: false,
        smart_input_placeholder: "Write something meaningful",
        page_title: "Bonfire Dashboard",
        feed_title: "My Feed",
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

    def handle_params(_params, _url, socket) do
      {:noreply, socket}
    end

    defdelegate handle_params(params, attrs, socket), to: Bonfire.Web.LiveHandler
    def handle_event(action, attrs, socket), do: Bonfire.Web.LiveHandler.handle_event(action, attrs, socket, __MODULE__)
    def handle_info(info, socket), do: Bonfire.Web.LiveHandler.handle_info(info, socket, __MODULE__)

  end
