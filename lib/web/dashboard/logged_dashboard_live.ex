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
      {:ok, socket
      |> assign(page_title: "Bonfire home page",
      feed_title: "My feed",
      feed: [],
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

  end
