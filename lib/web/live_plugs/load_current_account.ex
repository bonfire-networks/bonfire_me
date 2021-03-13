defmodule Bonfire.Web.LivePlugs.LoadCurrentAccount do

  use Bonfire.Web, :live_plug
  alias Bonfire.Me.Accounts
  alias Bonfire.Data.Identity.Account

  # the non-live plug already supplied the current account
  def mount(_, _, %{assigns: %{current_account: %Account{}}}=socket) do
    {:ok, socket}
  end

  def mount(_, session, socket) do
    {:ok,
     socket
     |> assign(current_account: Accounts.get_current(session["account_id"]))}
  end

end
