defmodule Bonfire.Me.Users.LiveHandler do
  use Bonfire.Web, :live_handler

  alias Bonfire.Me.Users
  def handle_event("autocomplete", %{"value"=>search}, socket), do: handle_event("autocomplete", search, socket)
  def handle_event("autocomplete", search, socket) when is_binary(search) do

    options = ( Users.search(search) || [] )
              |> Enum.map(&to_tuple/1)
    # IO.inspect(matches)

    {:noreply, socket |> assign_global(users_autocomplete: options) }
  end


  def to_tuple(u) do
    {e(u, :profile, :name, "Someone"), u.id}
  end
end
