defmodule Bonfire.Me.Web.LiveHandlers.Boundaries do
  use Bonfire.Web, :live_handler


  # def handle_event("post_input", %{"circles" => selected_circles} = _attrs, socket) when is_list(selected_circles) and length(selected_circles)>0 do

  #   previous_circles = e(socket, :assigns, :to_circles, []) #|> Enum.uniq()

  #   new_circles = set_circles(selected_circles, previous_circles)

  #   {:noreply,
  #       socket
  #       |> cast_self(
  #         to_circles: new_circles
  #       )
  #   }
  # end

  # def handle_event("post_input", _attrs, socket) do # no circle
  #   {:noreply,
  #     socket
  #       |> cast_self(
  #         to_circles: []
  #       )
  #   }
  # end

  def handle_event("boundary_select", %{"id" => selected} = _attrs, socket) when is_binary(selected) do

    previous_circles = e(socket, :assigns, :to_circles, []) |> IO.inspect

    new_circles = set_circles([selected], previous_circles, true) |> IO.inspect

    {:noreply,
        socket
        |> cast_self(
          to_circles: new_circles
        )
    }
  end

  def handle_event("boundary_deselect", %{"id" => deselected} = _attrs, socket) when is_binary(deselected) do

    new_circles = remove_from_circle_tuples([deselected], e(socket, :assigns, :to_circles, [])) |> IO.inspect

    {:noreply,
        socket
        |> cast_self(
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
    |> Enum.filter(& &1) |> Enum.uniq()
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

end
