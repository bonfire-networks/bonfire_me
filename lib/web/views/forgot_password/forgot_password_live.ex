defmodule Bonfire.Me.Web.ForgotPasswordLive do
  use Bonfire.UI.Common.Web, {:surface_view, [layout: {Bonfire.UI.Social.Web.LayoutView, "without_sidebar.html"}]}
  alias Bonfire.Me.Web.LivePlugs
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Web.ForgotPasswordController

  def mount(params, session, socket) do
    live_plug params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
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
