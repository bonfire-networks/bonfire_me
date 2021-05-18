defmodule Bonfire.Web.LivePlugs.AdminRequired do

  use Bonfire.Web, :live_plug
  alias Bonfire.Data.Identity.User

  def mount(_params, _session, socket), do: check(socket.assigns[:current_user], socket)

  defp check(%User{instance_admin: %{is_instance_admin: true}}, socket), do: {:ok, socket}
  defp check(_, socket) do
    {:halt,
     socket
     |> put_flash(:error, "That page is only accessible to instance administrators.")
     |> push_redirect(to: path(:login))}
  end

end
