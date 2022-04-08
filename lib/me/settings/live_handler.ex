defmodule Bonfire.Me.Settings.LiveHandler do
  use Bonfire.Web, :live_handler
  import Bonfire.Boundaries.Integration

  def handle_event("set", attrs, socket) when is_map(attrs) do
    with {:ok, status} <- attrs |> Map.drop(["_target"]) |> Bonfire.Me.Settings.set(socket) do
      {:noreply,
          socket
          |> put_flash(:info, status)
      }
    end
  end

end
