defmodule Bonfire.Me.Web.ForgotPasswordController do
  use Bonfire.Web, :controller

  def index(conn, _), do: live_render(conn, LoginLive)

  # def create(conn, _) do
  # end

end
