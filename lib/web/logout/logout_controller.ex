defmodule Bonfire.Me.Web.LogoutController do

  use Bonfire.Web, :controller

  def index(conn, _) do
    conn
    |> put_session(:account_id, nil)
    |> put_flash(:info, "Logged out!")
    |> redirect(to: "/")
  end

end
