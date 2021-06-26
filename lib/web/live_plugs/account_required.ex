defmodule Bonfire.Web.LivePlugs.AccountRequired do

  use Bonfire.Web, :live_plug
  alias Bonfire.Data.Identity.Account

  def mount(_params, _session, socket), do: check(e(socket.assigns, :current_account, nil), socket)

  defp check(%Account{}, socket), do: {:ok, socket}
  defp check(_, socket) do
    {:halt,
     socket
     |> put_flash(:error, l "You need to log in to view that page.")
     |> push_redirect(to: path(:login))}
  end

end
