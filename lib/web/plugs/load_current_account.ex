defmodule Bonfire.Me.Web.Plugs.LoadCurrentAccount do

  use Bonfire.UI.Common.Web, :plug
  alias Bonfire.Me.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    assign(conn, :current_account, Accounts.get_current(get_session(conn, :account_id)))
  end

end
