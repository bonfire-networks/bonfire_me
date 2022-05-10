defmodule Bonfire.Me.Settings.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Bonfire.Boundaries.Integration

  def handle_event("set", attrs, socket) when is_map(attrs) do
    with {:ok, _settings} <- Map.drop(attrs, ["_target"]) |> Bonfire.Me.Settings.set(socket) do
      {:noreply,
          socket
          |> put_flash(:info, "Settings saved :-)")
      }
    end
  end

  def handle_event("save", attrs, socket) when is_map(attrs) do
    with {:ok, _settings} <- Map.drop(attrs, ["_target"]) |> Bonfire.Me.Settings.set(socket) do
      {:noreply,
          socket
          |> push_redirect(to: "/")
          |> put_flash(:info, "Settings saved :-)")
      }
    end |> debug()
  end


end
