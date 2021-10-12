defmodule Bonfire.Me.Web.ChangePasswordLive do
  use Bonfire.Web, {:live_view, [layout: {Bonfire.UI.Social.Web.LayoutView, "without_sidebar.html"}]}
  alias Bonfire.Web.LivePlugs
  alias Bonfire.Me.Accounts

  def mount(params, session, socket) do
    LivePlugs.live_plug params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      # LivePlugs.LoadCurrentUser,
      LivePlugs.StaticChanged,
      LivePlugs.Csrf,
      LivePlugs.Locale,
      &mounted/3
    ]
  end

  def mounted(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:form, &form_cs/0)}
  end

  defp form_cs(), do: Accounts.changeset(:change_password, %{})
end
