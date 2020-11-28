defmodule Bonfire.Me.Web.ConfirmEmailLive do
  use Bonfire.Web, :live_view
  alias Bonfire.Me.Web.HeroProfileLive
  alias Bonfire.Me.Web.ProfileNavigationLive
  alias Bonfire.Me.Web.ProfileAboutLive
  alias Bonfire.Me.Fake
  alias Bonfire.Common.Web.LivePlugs
  alias Bonfire.Me.Identity.Accounts

  def mount(params, session, socket) do
    {:ok,
     socket
     |> assign_new(:error, fn -> nil end)
     |> assign_new(:current_account, fn -> nil end)
     |> assign_new(:current_user, fn -> nil end)
     |> assign_new(:requested, fn -> false end)
     |> assign_new(:form, &form/0)}
  end

  defp form(), do: Accounts.changeset(:confirm_email, %{})

end
