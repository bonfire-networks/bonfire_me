defmodule Bonfire.Me.Web.ResetPasswordLive do
  use Bonfire.Web, :live_view
  alias Bonfire.Common.Web.LivePlugs

  def mount(params, session, socket) do
    LivePlugs.live_plug params, session, socket, [
      LivePlugs.LoadSessionAuth,
      LivePlugs.StaticChanged,
      LivePlugs.Csrf,
      &mounted/3,
    ]
  end

  defp mounted(_params, _session, socket), do: {:ok, socket}

end
