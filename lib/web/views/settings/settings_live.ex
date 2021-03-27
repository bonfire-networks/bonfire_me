defmodule Bonfire.Me.Web.SettingsLive do
  use Bonfire.Web, {:live_view, [layout: {Bonfire.Web.LayoutView, "settings_template.html"}]}

  alias Bonfire.Me.Fake
  alias Bonfire.Me.Users

  alias Bonfire.Me.Web.SettingsLive.{
    SettingsNavigationLive,
    EditProfileLive,
    ExtensionsLive,
    EditAccountLive,
    AdminLive
  }
  alias Bonfire.Web.LivePlugs

  def mount(params, session, socket) do
    LivePlugs.live_plug params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      LivePlugs.StaticChanged,
      LivePlugs.Csrf,
      &mounted/3,
    ]
  end

  defp mounted(params, session, socket),
    do: {:ok,
         socket
         |> assign(
         page_title: "Settings",
         selected_tab: "user",
         trigger_submit: false,
         )}

  def handle_params(%{"tab" => tab}, _url, socket) do
    {:noreply, assign(socket, selected_tab: tab)}
  end

  def handle_params(_, _url, socket) do
    {:noreply, socket}
  end

  def handle_event(action, attrs, socket), do: Bonfire.Web.LiveHandler.handle_event(action, attrs, socket, __MODULE__)

end
