defmodule Bonfire.Me.Web.SettingsLive do
  use Bonfire.Web, {:live_view, [layout: {Bonfire.Web.LayoutView, "without_sidebar.html"}]}

  alias Bonfire.Me.Fake
  alias Bonfire.Me.Identity.Users

  alias Bonfire.Me.Web.SettingsLive.{
    SettingsNavigationLive,
    EditProfileLive,
    ExtensionsLive,
    EditAccountLive
  }
  alias Bonfire.Common.Web.LivePlugs

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

  def handle_event("profile_save", _data, %{assigns: %{trigger_submit: trigger_submit}} = socket)
      when trigger_submit == true do
    {
      :noreply,
      assign(socket, trigger_submit: false)
    }
  end

  def handle_event("profile_save", params, socket) do
  undead(socket, fn ->
  # params = input_to_atoms(params)

    with {:ok, edit_profile} <-
      Users.update(socket.assigns.current_user, params, socket.assigns.current_account) do

      IO.inspect((Map.get(params, "icon")))
      cond do
      # handle controller-based upload
        strlen(Map.get(params, "icon")) > 0 or strlen(Map.get(params, "image")) > 0 ->
          {
            :noreply,
            assign(socket, trigger_submit: true)
            |> put_flash(:info, "Details saved!")
            #  |> push_redirect(to: "/user")
          }

        true ->
          {:noreply,
          socket
          |> put_flash(:info, "Profile saved!")
          |> push_redirect(to: "/user")
          }
      end
    end
  end)
  end
end
