defmodule Bonfire.Me.Web.SwitchUserLive do
  use Bonfire.Web, :live_view
  alias Bonfire.Fake
  alias Bonfire.Common.Web.LivePlugs
  alias Bonfire.Me.Users

  def mount(params, session, socket) do
    LivePlugs.live_plug params, session, socket, [
      LivePlugs.LoadSessionAuth,
      LivePlugs.StaticChanged,
      LivePlugs.Csrf,
      LivePlugs.AuthRequired,
      &mounted/3,
    ]
  end

  defp mounted(params, session, socket) do
    IO.inspect("switcher")
    {:ok, socket
    |> assign(page_title: "Switch User",
    selected_tab: "about",
    current_account: socket.assigns.current_account,
    users: Users.by_account(socket.assigns.current_account))}

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
