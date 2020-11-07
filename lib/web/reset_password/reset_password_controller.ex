defmodule Bonfire.Me.Web.ResetPasswordController do
  use Bonfire.WebPhoenix, [:controller]

  plug Bonfire.Me.Web.Plugs.MustBeGuest

  def index(conn, %{"token" => token}) do
  end

  def create(conn, %{"token" => token}) do
  end

end
