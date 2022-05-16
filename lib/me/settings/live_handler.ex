defmodule Bonfire.Me.Settings.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Bonfire.Boundaries.Integration

  def handle_event("set", attrs, socket) when is_map(attrs) do
    with {:ok, settings} <- Map.drop(attrs, ["_target"]) |> Bonfire.Me.Settings.set(socket) do
      # debug(settings, "done")
      {:noreply,
          socket
          |> maybe_assign_context(settings)
          |> put_flash(:info, "Settings saved :-)")
      }
    end
  end

  def handle_event("save", attrs, socket) when is_map(attrs) do
    with {:ok, settings} <- Map.drop(attrs, ["_target"]) |> Bonfire.Me.Settings.set(socket) do
      {:noreply,
          socket
          |> maybe_assign_context(settings)
          |> put_flash(:info, "Settings saved :-)")
          |> push_redirect(to: "/")
      }
    end
  end

  defp maybe_assign_context(socket, %{assign_context: assigns}) do
    socket
    |> assign_global(assigns)
  end
  defp maybe_assign_context(socket, _), do: socket
end
