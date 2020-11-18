defmodule Bonfire.Me.Web.LoginController do

  use Bonfire.Web, :controller
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Web.LoginPageLive
  import Phoenix.LiveView.Controller

  def index(conn, _), do: live_render(conn, LoginPageLive, current_account: nil, error: nil, form: form())

  def create(conn, params) do
    form = Map.get(params, "login_fields", %{})
    case Accounts.login(Accounts.changeset(:login, form)) do
      {:ok, account} ->
        logged_in(account, conn)
      {:error, error} when is_atom(error) ->
        render(conn, "form.html", current_account: nil, error: error, form: form())
      {:error, changeset} ->
        render(conn, "form.html", current_account: nil, error: nil, form: changeset)
    end
  end

  defp form(params \\ %{}), do: Accounts.changeset(:login, params)

  defp logged_in(account, conn) do
    conn
    |> put_session(:account_id, account.id)
    |> redirect(to: "/~")
  end

end
