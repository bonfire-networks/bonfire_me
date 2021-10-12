defmodule Bonfire.Me.Web.SignupLive do
  use Bonfire.Web, {:live_view, [layout: {Bonfire.UI.Social.Web.LayoutView, "empty_template.html"}]}
  alias Bonfire.Me.Accounts

  # because this isn't a live link and it will always be accessed by a
  # guest, it will always be offline
  def mount(params, session, socket) do
    # IO.inspect(session: session)
    {:ok,
     socket
      |> assign_new(:current_account, fn -> nil end)
      |> assign_new(:current_user, fn -> nil end)
      |> assign_new(:registered, fn -> false end)
      |> assign_new(:error, fn -> nil end)
      |> assign_new(:form, fn -> form_cs(session) end)}
  end

  defp form_cs(%{"invite" => invite}), do: Accounts.changeset(:signup, %{}, invite: invite)
  defp form_cs(_), do: Accounts.changeset(:signup, %{})

end
