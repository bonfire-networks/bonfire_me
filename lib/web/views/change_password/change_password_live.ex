defmodule Bonfire.Me.Web.ChangePasswordLive do
  use Bonfire.Web, {:surface_view, [layout: {Bonfire.UI.Social.Web.LayoutView, "without_sidebar.html"}]}
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

  def mounted(_params, session, socket) do
    {:ok,
     socket
     |> assign(:form,  session["form"])
     |> assign(:error,  session["error"])
     |> assign(:resetting_password,  session["resetting_password"])
     |> assign_new(:form, &ChangePasswordController.form_cs/0)}
  end

end
