defmodule Bonfire.Me.Web.LoggedDashboardLive do
    use Bonfire.Web, :live_view
    alias Bonfire.Web.LivePlugs

    def mount(params, session, socket) do
      LivePlugs.live_plug params, session, socket, [
        LivePlugs.LoadCurrentAccount,
        LivePlugs.LoadCurrentUser,
        LivePlugs.LoadCurrentAccountUsers,
        LivePlugs.LoadCurrentUserCircles,
        LivePlugs.StaticChanged,
        LivePlugs.Csrf, LivePlugs.Locale,
        &mounted/3,
      ]
    end

    defp mounted(_params, _session, socket) do

      feed_module = if module_enabled?(Bonfire.Social.Web.Feeds.BrowseLive), do: Bonfire.UI.Social.BrowseViewLive,
      else: Bonfire.UI.Social.FeedViewLive


      {:ok, socket
      |> assign(
        page: "dashboard",
        smart_input: true,
        has_private_tab: false,
        smart_input_placeholder: "Write something meaningful",
        page_title: "Bonfire Dashboard",
        feed_title: "My Feed",
        feed_module: feed_module,
        selected_tab: "feed",
        go: ""
        )
        |> cast_self(to_circles: Bonfire.Me.Users.Circles.list_my_defaults(socket))
      }
    end

    # def handle_params(%{"tab" => tab} = _params, _url, socket) do
    #   {:noreply,
    #    assign(socket,
    #      selected_tab: tab
    #    )}
    # end

    defdelegate handle_params(params, attrs, socket), to: Bonfire.Web.LiveHandler
    def handle_event(action, attrs, socket), do: Bonfire.Web.LiveHandler.handle_event(action, attrs, socket, __MODULE__)
    def handle_info(info, socket), do: Bonfire.Web.LiveHandler.handle_info(info, socket, __MODULE__)

  end
