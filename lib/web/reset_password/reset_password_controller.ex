defmodule Bonfire.Me.Web.ResetPasswordController do
  use Bonfire.Web, :controller
  alias Bonfire.Me.Web.ResetPasswordLive

  def index(conn, _) do
    conn
    |> live_render_with_conn(ResetPasswordLive)
  end

  def create(conn, _) do
    conn
    |> live_render_with_conn(ResetPasswordLive)
  end

end
