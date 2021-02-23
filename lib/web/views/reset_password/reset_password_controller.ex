defmodule Bonfire.Me.Web.ResetPasswordController do
  use Bonfire.Web, :controller
  alias Bonfire.Me.Web.ResetPasswordLive

  def index(conn, _) do
    conn
    |> live_render(ResetPasswordLive)
  end

  def create(conn, _) do
    conn
    |> live_render(ResetPasswordLive)
  end

end
