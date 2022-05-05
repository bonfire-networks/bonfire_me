defmodule Bonfire.Me.Web.ChangePasswordLive do
  use Bonfire.UI.Common.Web, :surface_view
  alias Bonfire.Me.Web.LivePlugs
  alias Bonfire.Me.Accounts

  def mount(params, session, socket) do
    live_plug params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      # LivePlugs.LoadCurrentUser,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
      &mounted/3
    ]
  end

  def mounted(_params, session, socket) do
    {:ok,
     socket
     |> assign(:without_sidebar,  true)
     |> assign(:form,  session["form"])
     |> assign(:error,  session["error"])
     |> assign(:resetting_password,  session["resetting_password"])
     |> assign_new(:form, &ChangePasswordController.form_cs/0)}
  end

end
