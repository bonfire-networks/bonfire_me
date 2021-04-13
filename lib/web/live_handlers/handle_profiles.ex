defmodule Bonfire.Me.Web.LiveHandlers.Profiles do

  alias Bonfire.Common.Utils
  import Utils
  import Phoenix.LiveView

  alias Bonfire.Me.Users # TODO: use Profiles context instead?

  def handle_event("profile_save", _data, %{assigns: %{trigger_submit: trigger_submit}} = socket)
      when trigger_submit == true do
    {
      :noreply,
      assign(socket, trigger_submit: false)
    }
  end

  def handle_event("profile_save", params, socket) do
  # params = input_to_atoms(params)

    with {:ok, _edit_profile} <-
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
  end
end
