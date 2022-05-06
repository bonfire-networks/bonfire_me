defmodule Bonfire.Me.Web.SignupLive do
  use Bonfire.UI.Common.Web, :surface_view
  alias Bonfire.Me.Accounts

  # because this isn't a live link and it will always be accessed by a
  # guest, it will always be offline
  def mount(params, session, socket) do
    debug(session: session)
    {:ok,
     socket
      |> assign(:invite, e(session, "invite", nil))
      |> assign(:registered, e(session, "registered", nil))
      |> assign_new(:without_sidebar, fn -> true end)
      |> assign_new(:current_account, fn -> nil end)
      |> assign_new(:current_user, fn -> nil end)
      |> assign_new(:error, fn -> nil end)
      |> assign_new(:form, fn -> form_cs(session) end)
    }
  end

  defp form_cs(%{"invite" => invite}), do: Accounts.changeset(:signup, %{}, invite: invite)
  defp form_cs(_), do: Accounts.changeset(:signup, %{})

end
