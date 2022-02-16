defmodule Bonfire.Web.LivePlugs.LoadCurrentUserCircles do

  use Bonfire.Web, :live_plug
  alias Bonfire.Me.Boundaries.Circles
  alias Bonfire.Data.Identity.User

  def mount(_, _, %{assigns: %{current_user: %User{} = user}} = socket) do
    {:ok, assign(socket, :my_circles, Circles.list_my(user))}
  end

  def mount(_, _, %{assigns: %{__context__:  %{current_user: %User{} = user}}} = socket) do
    {:ok, assign(socket, :my_circles, Circles.list_my(user))}
  end

  def mount(_, _, socket) do
    {:ok, assign(socket, :my_circles, [])}
  end

end
