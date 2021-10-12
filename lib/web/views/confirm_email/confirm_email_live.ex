defmodule Bonfire.Me.Web.ConfirmEmailLive do
  use Bonfire.Web, {:live_view, [layout: {Bonfire.UI.Social.Web.LayoutView, "without_sidebar.html"}]}
  alias Bonfire.Me.Accounts

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:error, fn -> nil end)
     |> assign_new(:current_account, fn -> nil end)
     |> assign_new(:current_user, fn -> nil end)
     |> assign_new(:requested, fn -> false end)
     |> assign_new(:form, &form_cs/0)}
  end

  defp form_cs(), do: Accounts.changeset(:confirm_email, %{})

end
