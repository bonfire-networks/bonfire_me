defmodule Bonfire.Me.Web.CreateUserLive do
  use Bonfire.Web, {:live_view, [layout: {Bonfire.Web.LayoutView, "without_sidebar.html"}]}
  # alias Bonfire.Data.Identity.User
  alias Bonfire.Me.Users
  alias Bonfire.Web.LivePlugs
  # alias Bonfire.Me.Web.CreateUserLive

  def mount(params, session, socket) do
    LivePlugs.live_plug params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      LivePlugs.AccountRequired,
      LivePlugs.StaticChanged,
      LivePlugs.Csrf,
      &mounted/3,
    ]
  end

  defp mounted(_params, _session, socket) do
    {:ok,
     socket
     |> assign(form: form(socket.assigns.current_account))}
  end

  defp form(params \\ %{}, account), do: Users.changeset(:create, params, account)

end
