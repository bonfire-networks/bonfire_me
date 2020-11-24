defmodule Bonfire.Me.Web.LogoutController do

  use Bonfire.Web, :controller

  def index(conn, _) do
    conn
    |> delete_session(:account_id)
    |> put_flash(:info, "Logged out successfully. Until next time!")
    |> redirect(to: Routes.home_path(conn, :index))
  end

end
