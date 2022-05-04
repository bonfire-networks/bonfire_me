defmodule Bonfire.Me.Web.Plugs.GuestOnly do

  use Bonfire.UI.Common.Web, :plug

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:current_account] || conn.assigns[:current_user],
      do: not_permitted(conn),
      else: conn
  end

  defp not_permitted(conn) do
    conn
    |> put_flash(:error, "That page is only accessible to guests.")
    |> redirect(to: path(:home))
    |> halt()
  end

end
