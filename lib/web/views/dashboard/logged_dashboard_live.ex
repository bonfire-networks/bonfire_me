defmodule Bonfire.Me.Web.LoggedDashboardLive do
  @deprecated
  use Bonfire.Web, {:surface_view, [layout: {Bonfire.UI.Social.Web.LayoutView, "without_sidebar.html"}]}
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

      {:ok, socket
      |> assign(
        page: "dashboard",
        smart_input: true,
        has_private_tab: false,
        page_title: l("Bonfire Dashboard"),
        feed_title: l("My Feed"),
        selected_tab: "feed",
        go: ""
        )
        # |> assign_global(to_circles: Bonfire.Boundaries.Circles.list_my_defaults(socket))
      }
    end

    # def handle_params(%{"tab" => tab} = _params, _url, socket) do
    #   {:noreply,
    #    assign(socket,
    #      selected_tab: tab
    #    )}
    # end

    defdelegate handle_params(params, attrs, socket), to: Bonfire.Common.LiveHandlers
    def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
    def handle_info(info, socket), do: Bonfire.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

  end
