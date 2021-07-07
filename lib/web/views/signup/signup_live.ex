defmodule Bonfire.Me.Web.SignupLive do
  use Bonfire.Web, {:live_view, [layout: {Bonfire.UI.Social.Web.LayoutView, "empty_template.html"}]}
  alias Bonfire.Me.Accounts

  # because this isn't a live link and it will always be accessed by a
  # guest, it will always be offline
  def mount(_params, _session, socket) do
    {:ok,
     socket
      |> assign_new(:current_account, fn -> nil end)
      |> assign_new(:current_user, fn -> nil end)
      |> assign_new(:registered, fn -> false end)
      |> assign_new(:error, fn -> nil end)
      |> assign_new(:form, &form/0)}
  end

  defp form(), do: Accounts.changeset(:signup, %{})

end
