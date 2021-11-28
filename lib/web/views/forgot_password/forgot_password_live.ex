defmodule Bonfire.Me.Web.ForgotPasswordLive do
  use Bonfire.Web, :surface_view
  alias Bonfire.Web.LivePlugs
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Web.ForgotPasswordController

  def mount(params, session, socket) do
    LivePlugs.live_plug params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      LivePlugs.StaticChanged,
      LivePlugs.Csrf, LivePlugs.Locale,
      &mounted/3,
    ]
  end

  defp mounted(_params, session, socket) do
    {:ok,
     socket
      |> assign(:form, ForgotPasswordController.form)
      |> assign(:error,  session["error"])
      |> assign(:requested, session["requested"])
    }
  end


end
