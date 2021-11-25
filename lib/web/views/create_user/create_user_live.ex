defmodule Bonfire.Me.Web.CreateUserLive do
  use Bonfire.Web, {:surface_view, [layout: {Bonfire.UI.Social.Web.LayoutView, "without_sidebar.html"}]}
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
      LivePlugs.Csrf, LivePlugs.Locale,
      &mounted/3,
    ]
  end

  defp mounted(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:form, fn -> user_form(e(socket.assigns, :current_account, nil)) end )
     |> assign_new(:error, fn -> nil end)
    }
  end

  defp user_form(params \\ %{}, account), do: Users.changeset(:create, params, account)

end
