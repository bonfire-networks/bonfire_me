defmodule Bonfire.Me.Web.LivePlugs.UserRequired do

  use Bonfire.UI.Common.Web, :live_plug
  alias Bonfire.Data.Identity.{Account, User}
  # alias Plug.Conn.Query

  def mount(_params, _session, %{assigns: the}=socket) do
    check(e(the, :current_user, nil), e(the, :current_account, nil), socket)
  end

  defp check(%User{}, _account, socket), do: {:ok, socket}

  defp check(_user, %Account{}, socket) do
    {:halt,
     socket
     |> put_flash(:info, l "You need to choose a user to see that page.")
     |> push_redirect(to: path(:switch_user))}
  end

  defp check(_user, _account, socket) do
    {:halt,
     socket
     |> put_flash(:info, l "You need to log in to see that page.")
     |> push_redirect(to: path(:login))}
  end

end
