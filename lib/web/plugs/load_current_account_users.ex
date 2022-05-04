defmodule Bonfire.Me.Web.Plugs.LoadCurrentAccountUsers do

  use Bonfire.UI.Common.Web, :plug
  alias Bonfire.Me.Users
  alias Bonfire.Data.Identity.Account

  def init(opts), do: opts

  def call(%{assigns: %{current_account: %Account{}=account}}=conn, _opts) do
    assign(conn, :current_account_users, Users.by_account(account))
  end

  def call(conn, _opts), do: conn

end
