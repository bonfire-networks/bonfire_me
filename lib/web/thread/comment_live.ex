defmodule Bonfire.Me.Web.CommentLive do
  use Bonfire.Web, :live_component

  def update(assigns, socket) do


    {:ok, assign(socket, assigns
    |> Map.merge(%{
        date_ago: date_from_now(assigns.comment),
      })) }
  end


end
