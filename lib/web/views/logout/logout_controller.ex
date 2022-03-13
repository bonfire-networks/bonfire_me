defmodule Bonfire.Me.Web.LogoutController do

  use Bonfire.Web, :controller

  def index(conn, _) do
    conn
    |> delete_session(:account_id)
    |> clear_session()
    |> put_flash(:info, l "Logged out successfully. Until next time!")
    |> redirect(to: path(:home))
  end

end
