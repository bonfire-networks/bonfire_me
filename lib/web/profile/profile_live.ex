defmodule Bonfire.Me.Web.ProfileLive do
  use Bonfire.WebPhoenix, [:live_view]
  alias Bonfire.Me.Web.HeroProfileLive
  alias Bonfire.Me.Web.ProfileNavigationLive
  alias Bonfire.Me.Web.ProfileAboutLive
  alias Bonfire.Me.Fake


  @impl true
  def mount(params, session, socket) do
    socket = init_assigns(params, session, socket)

    user = if e(socket.assigns, :current_user, :id, nil) do
      socket.assigns.current_user
    else
      Fake.user_live()
    end

    {:ok,
     socket
     |> assign(
       page_title: "User",
       selected_tab: "about",
       user: user
     )}
  end

  def handle_params(%{"tab" => tab} = _params, _url, socket) do
    {:noreply,
     assign(socket,
       selected_tab: tab
     )}
  end

  def handle_params(%{} = _params, _url, socket) do
    {:noreply,
     assign(socket,
      selected_tab: "about"
      #  current_user: Fake.user_live()
     )}
  end

end
