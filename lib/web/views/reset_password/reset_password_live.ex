defmodule Bonfire.Me.Web.ResetPasswordLive do
  use Bonfire.Web, :live_view
  # alias Bonfire.Web.LivePlugs

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(current_account: nil)
     |> assign(current_user: nil)
    }
  end
  #   LivePlugs.live_plug params, session, socket, [
  #     LivePlugs.LoadCurrentAccount,
  #     LivePlugs.StaticChanged,
  #     LivePlugs.Csrf, LivePlugs.Locale,
  #     &mounted/3,
  #   ]
  # end

  # defp mounted(_params, _session, socket), do: {:ok, socket}

end
