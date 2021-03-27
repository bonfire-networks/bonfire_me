defmodule Bonfire.Me.Web.LiveHandlers.Circles do

  alias Bonfire.Common.Utils
  import Utils
  import Phoenix.LiveView

  alias Bonfire.Me.Users.Circles


  def handle_event("circle_create", %{"name" => name}, socket) do
  # params = input_to_atoms(params)

    with {:ok, circle} <-
      Circles.create(socket.assigns.current_user, name) do

          {:noreply,
          socket
          |> put_flash(:info, "Circle create!")
          |> push_redirect(to: "/settings/circle/"<>circle.id)
          }

    end
  end

  def handle_event("circle_member_update", %{"circle" => %{"id" => id} = params}, socket) do
    # params = input_to_atoms(params)

      with {:ok, circle} <-
        Circles.update(id, socket.assigns.current_user, %{encircles: e(params, "encircle", [])}) do

            {:noreply,
            socket
            |> put_flash(:info, "OK")
            }

      end
    end
end
