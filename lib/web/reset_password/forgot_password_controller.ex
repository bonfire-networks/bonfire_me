defmodule Bonfire.Me.Web.ForgotPasswordController do
  use Bonfire.WebPhoenix, [:controller]

  plug Bonfire.Me.Web.Plugs.MustBeGuest

  def index(conn, _) do
  end

  def create(conn, _) do
  end

end
