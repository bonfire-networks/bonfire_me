defmodule CommonsPub.Me.Web.ForgotPasswordController do
  use CommonsPub.WebPhoenix, [:controller]

  plug CommonsPub.Me.Web.Plugs.MustBeGuest

  def index(conn, _) do
  end

  def create(conn, _) do
  end

end
