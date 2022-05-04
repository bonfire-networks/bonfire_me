defmodule Bonfire.Me.Web.LogoutController do

  use Bonfire.UI.Common.Web, :controller

  def index(conn, _) do
    conn
    |> delete_session(:account_id)
    |> clear_session()
    |> put_flash(:info, l "Logged out successfully. Until next time!")
    |> redirect(to: path(:home))
    |> redirect(go_where?(conn, conn.query_params, path(:login)))
  end

end
