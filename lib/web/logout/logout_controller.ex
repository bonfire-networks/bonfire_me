defmodule Bonfire.Me.Web.LogoutController do

  use Phoenix.Controller, [:controller]

  def index(conn, _) do
    conn |>
    logout()
  end


  defp logout(conn) do
    conn
    |> put_session(:account_id, nil)
    |> redirect(to: "/")
  end

end
