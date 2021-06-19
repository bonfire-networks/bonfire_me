defmodule Bonfire.Me.Web.ChangePasswordController do
  use Bonfire.Web, :controller
  alias Bonfire.Me.Web.ChangePasswordLive

  def index(conn, _) do
    conn
    |> live_render(ChangePasswordLive)
  end

  def create(conn, _) do
    conn
    |> live_render(ChangePasswordLive)
  end

end
