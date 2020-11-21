defmodule Bonfire.Me.Web.SignupLive do
  use Bonfire.Web, :live_view
  alias Bonfire.Me.Web.HeroProfileLive
  alias Bonfire.Me.Web.ProfileNavigationLive
  alias Bonfire.Me.Web.ProfileAboutLive
  alias Bonfire.Me.Fake
  alias Bonfire.Common.Web.LivePlugs

  def mount(params, session, socket) do
    LivePlugs.live_plug params, session, socket, [
      LivePlugs.LoadSessionAuth,
      LivePlugs.StaticChanged,
      LivePlugs.Csrf,
      &mounted/3,
    ]
  end

  defp mounted(params, session, socket) do
    user = e(socket.assigns, :current_user, Fake.user_live())
    {:ok,
       socket
       |> assign(
         page_title: "User",
         selected_tab: "about",
         user: user,
         current_user: user
       )}
  end
end
