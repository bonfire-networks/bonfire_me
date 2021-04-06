defmodule Bonfire.Me.Web.LoginController do

  use Bonfire.Web, :controller
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Web.LoginLive
  alias Bonfire.Common.Web.Misc
  alias Bonfire.Common.Utils

  def index(conn, _) do # GET only supports 'go'
    conn = fetch_query_params(conn)
    paint(conn, form(Map.take(conn.query_params, [:go, "go"])))
  end

  def create(conn, params) do
    params = Map.get(params, "login_fields", %{})
    form = Accounts.changeset(:login, params)
    case Accounts.login(form) do
      {:ok, account} -> logged_in(account, conn, form)
      {:error, changeset} -> paint(conn, changeset)
    end
  end

  defp form(params \\ %{}), do: Accounts.changeset(:login, params)

  defp logged_in(account, conn, form) do
    IO.inspect(account)
    conn
    |> put_session(:account_id, account.id)
    |> put_session(:user_id, Utils.e(account, :accounted, :user, :id, nil))
    |> put_flash(:info, "Welcome back!")
    |> redirect(to: Misc.go_where?(conn, form, Routes.live_path(conn, Bonfire.Me.Web.LoggedDashboardLive)))
  end

  defp paint(conn, changeset) do
    conn
    |> assign(:form, changeset)
    |> live_render(LoginLive)
  end

end
