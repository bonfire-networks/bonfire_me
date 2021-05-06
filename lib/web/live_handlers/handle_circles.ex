defmodule Bonfire.Me.Web.LiveHandlers.Circles do
  use Bonfire.Web, :live_handler

  alias Bonfire.Me.Users.Circles


  def handle_event("circle_create", %{"name" => name}, socket) do
  # params = input_to_atoms(params)

    with {:ok, %{id: id} = _circle} <-
      Circles.create(socket.assigns.current_user, name) do

          {:noreply,
          socket
          |> put_flash(:info, "Circle create!")
          |> push_redirect(to: "/settings/circle/"<>id)
          }

    end
  end

  def handle_event("circle_member_update", %{"circle" => %{"id" => id} = params}, socket) do
    # params = input_to_atoms(params)

      with {:ok, _circle} <-
        Circles.update(id, socket.assigns.current_user, %{encircles: e(params, "encircle", [])}) do

            {:noreply,
            socket
            |> put_flash(:info, "OK")
            }

      end
    end
end
