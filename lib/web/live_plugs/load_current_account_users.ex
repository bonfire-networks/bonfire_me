defmodule Bonfire.Me.Web.LivePlugs.LoadCurrentAccountUsers do

  use Bonfire.UI.Common.Web, :live_plug
  alias Bonfire.Me.Users
  alias Bonfire.Data.Identity.Account

  # from the plug
  def mount(_, _, %{assigns: %{current_account_users: _}}=socket) do
    {:ok, socket}
  end

  # pull from account
  def mount(_, _, %{assigns: %{current_account: %Account{}=account}}=socket) do
    {:ok, assign(socket, current_account_users: Users.by_account(account))}
  end

  def mount(_, _, %{assigns: %{__context__: %{current_account: %Account{}=account}}}=socket) do
    {:ok, assign(socket, current_account_users: Users.by_account(account))}
  end

  def mount(_, _, socket), do: {:ok, assign(socket, :current_account_users, [])}

end
