defmodule Bonfire.Me.Web.SettingsLive do
  use Bonfire.Web, :live_view

  alias Bonfire.Me.Fake

  alias Bonfire.Me.Web.SettingsLive.{
    SettingsNavigationLive,
    SettingsGeneralLive
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
         selected_tab: "general",
         trigger_submit: false,
         current_user: Fake.user_live()
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
    params = input_to_atoms(params)

    {:ok, _edit_profile} =
      UsersResolver.update_profile(params, %{
        context: %{current_user: socket.assigns.current_user}
      })

    cond do
      strlen(params.icon) > 0 or strlen(params.image) > 0 ->
        {
          :noreply,
          assign(socket, trigger_submit: true)
          |> put_flash(:info, "Details saved!")
          #  |> push_redirect(to: "/~/profile")
        }

      true ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile saved!")
         |> push_redirect(to: "/~/profile")}
    end
  end
end
