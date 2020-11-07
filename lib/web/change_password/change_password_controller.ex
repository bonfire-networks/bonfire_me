defmodule Bonfire.Me.Web.ChangePasswordController do
  use Bonfire.WebPhoenix, [:controller]

  plug Bonfire.Me.Web.Plugs.MustLogIn, load_account: true

  def index(conn, _) do
  end

  def create(conn, _) do
  end

end
