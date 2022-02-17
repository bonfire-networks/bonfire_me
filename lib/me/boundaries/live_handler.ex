defmodule Bonfire.Me.Boundaries.LiveHandler do
  use Bonfire.Web, :live_handler

  def handle_event("block", %{"id" => id, "scope" => "instance"} = _attrs, socket) when is_binary(id) do
    if Bonfire.Me.Users.is_admin?(current_user(socket)), do: Bonfire.Me.Boundaries.block(id, :instance) |> debug, else: raise "Not admin"
    # TODO: show feedback
    {:noreply,
        socket
    }
  end

  def handle_event("block", %{"id" => id} = _attrs, socket) when is_binary(id) do
    Bonfire.Me.Boundaries.block(id, socket) |> debug
    # TODO: show feedback
    {:noreply,
        socket
    }
  end

  # def handle_event("input", %{"circles" => selected_circles} = _attrs, socket) when is_list(selected_circles) and length(selected_circles)>0 do

  #   previous_circles = e(socket, :assigns, :to_circles, []) #|> Enum.uniq()

  #   new_circles = set_circles(selected_circles, previous_circles)

  #   {:noreply,
  #       socket
  #       |> assign_global(
  #         to_circles: new_circles
  #       )
  #   }
  # end

  # def handle_event("input", _attrs, socket) do # no circle
  #   {:noreply,
  #     socket
  #       |> assign_global(
  #         to_circles: []
  #       )
  #   }
  # end

  def handle_event("select", %{"id" => selected} = _attrs, socket) when is_binary(selected) do

    previous_circles = e(socket, :assigns, :to_circles, []) #|> IO.inspect

    new_circles = set_circles([selected], previous_circles, true) #|> IO.inspect

    {:noreply,
        socket
        |> assign_global(
          to_circles: new_circles
        )
    }
  end

  def handle_event("deselect", %{"id" => deselected} = _attrs, socket) when is_binary(deselected) do

    new_circles = remove_from_circle_tuples([deselected], e(socket, :assigns, :to_circles, [])) #|> IO.inspect

    {:noreply,
        socket
        |> assign_global(
          to_circles: new_circles
        )
    }
  end

  def set_circles(selected_circles, previous_circles, add_to_previous \\ false) do

    # IO.inspect(previous_circles: previous_circles)
    # selected_circles = Enum.uniq(selected_circles)

    # IO.inspect(selected_circles: selected_circles)

    previous_ids = previous_circles |> Enum.map(fn
        {_name, id} -> id
        _ -> nil
      end)
    # IO.inspect(previous_ids: previous_ids)

    public = Bonfire.Boundaries.Circles.circles()[:guest]

    selected_circles = if public in selected_circles and public not in previous_ids do # public/guests defaults to also being visible to local users and federating
      selected_circles ++ [
        Bonfire.Boundaries.Circles.circles()[:local],
        Bonfire.Boundaries.Circles.circles()[:admin],
        Bonfire.Boundaries.Circles.circles()[:activity_pub]
      ]
    else
      selected_circles
    end

    # IO.inspect(new_selected_circles: selected_circles)

    existing = if add_to_previous, do: previous_circles, else: known_circle_tuples(selected_circles, previous_circles)


    # fix this ugly thing
    (
     existing
     ++
     Enum.map(selected_circles, &Bonfire.Boundaries.Circles.get_tuple/1)
    )
    |> Utils.filter_empty() |> Enum.uniq()
    # |> IO.inspect()
  end

  def known_circle_tuples(selected_circles, previous_circles) do
    previous_circles
    |> Enum.filter(fn
        {_name, id} -> id in selected_circles
        _ -> nil
      end)
  end

  def remove_from_circle_tuples(deselected_circles, previous_circles) do
    previous_circles
    |> Enum.filter(fn
        {_name, id} -> id not in deselected_circles
        _ -> nil
      end)
  end

    alias Bonfire.Me.Boundaries.Circles


  def handle_event("create_circle", %{"name" => name}, socket) do
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
