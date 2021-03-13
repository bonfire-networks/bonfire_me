defmodule Bonfire.Me.Web.LiveHandlers.Boosts do

  alias Bonfire.Common.Utils
  import Utils
  import Phoenix.LiveView

  def handle_event("boost", %{"id"=> id}, socket) do # boost in LV
    # IO.inspect(socket)
    with {:ok, _boost} <- Bonfire.Me.Social.Boosts.boost(socket.assigns.current_user, %{id: id}) do
      {:noreply, Phoenix.LiveView.assign(socket,
      boosted: Map.get(socket.assigns, :boosted, []) ++ [{id, true}]
    )}
    end
  end

  def handle_event("boost_undo", %{"id"=> id}, socket) do # unboost in LV
    with _ <- Bonfire.Me.Social.Boosts.unboost(socket.assigns.current_user, %{id: id}) do
      {:noreply, Phoenix.LiveView.assign(socket,
      boosted: Map.get(socket.assigns, :boosted, []) ++ [{id, false}]
    )}
    end
  end

end
