defmodule Bonfire.Me.Web.LiveHandlers.Likes do

  alias Bonfire.Common.Utils
  import Utils
  import Phoenix.LiveView

  def handle_event("like", %{"direction"=>"up", "id"=> id}, socket) do # like in LV
    IO.inspect(socket)
    with {:ok, _like} <- Bonfire.Me.Social.Likes.like(socket.assigns.current_user, %{id: id}) do
      {:noreply, Phoenix.LiveView.assign(socket,
      liked: Map.get(socket.assigns, :liked, []) ++ [{id, true}]
    )}
    end
  end

  def handle_event("like", %{"direction"=>"down", "id"=> id}, socket) do # unlike in LV
    with _ <- Bonfire.Me.Social.Likes.unlike(socket.assigns.current_user, %{id: id}) do
      {:noreply, Phoenix.LiveView.assign(socket,
      liked: Map.get(socket.assigns, :liked, []) ++ [{id, false}]
    )}
    end
  end

end
