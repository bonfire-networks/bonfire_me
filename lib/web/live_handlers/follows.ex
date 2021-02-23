defmodule Bonfire.Me.Web.LiveHandlers.Follows do

  alias Bonfire.Common.Utils
  import Utils
  import Phoenix.LiveView

  def handle_event("follow", _, socket) do
    with {:ok, _follow} <- Bonfire.Me.Social.Follows.follow(e(socket.assigns, :current_user, nil), e(socket.assigns, :user, nil)) do
      {:noreply, assign(socket,
       following: true
     )}
    else e ->
      {:noreply, socket} # TODO: handle errors
    end
  end

  def handle_event("unfollow", _, socket) do
    with _ <- Bonfire.Me.Social.Follows.unfollow(e(socket.assigns, :current_user, nil), e(socket.assigns, :user, nil)) do
      {:noreply, assign(socket,
       following: false
     )}
    else e ->
      {:noreply, socket} # TODO: handle errors
    end
  end

end
