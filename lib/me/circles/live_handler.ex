defmodule Bonfire.Me.Circles.LiveHandler do
  use Bonfire.Web, :live_handler

  alias Bonfire.Me.Users.Circles


  def handle_event("create", %{"name" => name}, socket) do
  # params = input_to_atoms(params)

    with {:ok, %{id: id} = _circle} <-
      Circles.create(current_user(socket), name) do

          {:noreply,
          socket
          |> put_flash(:info, "Circle create!")
          |> push_redirect(to: "/settings/circle/"<>id)
          }

    end
  end

  def handle_event("member_update", %{"circle" => %{"id" => id} = params}, socket) do
    # params = input_to_atoms(params)

      with {:ok, _circle} <-
        Circles.update(id, current_user(socket), %{encircles: e(params, "encircle", [])}) do

            {:noreply,
            socket
            |> put_flash(:info, "OK")
            }

      end
    end
end
