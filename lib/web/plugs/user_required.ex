defmodule Bonfire.Me.Web.Plugs.UserRequired do

  use Bonfire.UI.Common.Web, :plug
  alias Bonfire.Data.Identity.{Account, User}

  def init(opts), do: opts

  def call(%{assigns: the}=conn, _opts) do
    check(the[:current_user], the[:current_account], conn)
  end

  defp check(%User{}, _account, conn), do: conn

  defp check(_user, %Account{}, conn) do
    conn
    |> put_flash(:info, l "You need to choose a user to see that page.")
    |> set_go_after()
    |> redirect(to: path(:switch_user))
    |> halt()
  end

  defp check(_user, _account, conn) do
    conn
    |> clear_session()
    |> put_flash(:info, l "You need to log in to see that page.")
    |> set_go_after()
    |> redirect(to: path(:login))
    |> halt()
  end

end
