defmodule Bonfire.Me.Web.CommentLive do
  use Bonfire.Web, :live_component

  def update(assigns, socket) do


    {:ok, assign(socket, assigns
    |> Map.merge(%{
        date_ago: date_ago(assigns.comment.id),
      })) }
  end

  def date_ago(id) do
    with {:ok, ts} <- Pointers.ULID.timestamp(id) do
      date_from_now(ts)
    end
  end

end
