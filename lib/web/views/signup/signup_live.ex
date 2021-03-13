defmodule Bonfire.Me.Web.SignupLive do
  use Bonfire.Web, :live_view
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Web.HeroProfileLive
  alias Bonfire.Me.Web.ProfileNavigationLive
  alias Bonfire.Me.Web.ProfileAboutLive
  alias Bonfire.UI.Social.SignupLive
  alias Bonfire.Me.Fake
  alias Bonfire.Web.LivePlugs
  alias Ecto.Changeset

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
