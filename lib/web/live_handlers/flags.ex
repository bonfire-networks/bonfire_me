defmodule Bonfire.Me.Web.LiveHandlers.Flags do

  alias Bonfire.Common.Utils
  import Utils
  import Phoenix.LiveView

  def handle_event("flag", %{"id"=> id}, socket) do # flag in LV
    # IO.inspect(socket)
    with {:ok, _flag} <- Bonfire.Me.Social.Flags.flag(socket.assigns.current_user, %{id: id}) do
      {:noreply, Phoenix.LiveView.assign(socket,
      flagged: Map.get(socket.assigns, :flagged, []) ++ [{id, true}]
    )}
    end
  end

  def handle_event("flag_undo", %{"id"=> id}, socket) do # unflag in LV
    with _ <- Bonfire.Me.Social.Flags.unflag(socket.assigns.current_user, %{id: id}) do
      {:noreply, Phoenix.LiveView.assign(socket,
      flagged: Map.get(socket.assigns, :flagged, []) ++ [{id, false}]
    )}
    end
  end

end
