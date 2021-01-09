defmodule Bonfire.Me.Web.LogoutController do

  use Bonfire.Web, :controller
  alias Bonfire.Website.HomeGuestLive

  def index(conn, _) do
    conn
    |> delete_session(:account_id)
    |> clear_session()
    |> put_flash(:info, "Logged out successfully. Until next time!")
    |> redirect(to: Routes.live_path(conn, HomeGuestLive))
  end

end
