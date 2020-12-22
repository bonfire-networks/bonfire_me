defmodule Bonfire.Me.Web.LoginController do

  use Bonfire.Web, :controller
  alias Bonfire.Me.Identity.Accounts
  alias Bonfire.Me.Web.LoginLive

  def index(conn, _) do # GET only supports 'go'
    paint(conn, form(Map.take(conn.query_params, [:go])))
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
    conn
    |> put_session(:account_id, account.id)
    |> put_flash(:info, "Welcome back!")
    |> redirect(to: go_path(conn, form))
  end

  defp paint(conn, changeset) do
    conn
    |> assign(:form, changeset)
    |> live_render(LoginLive)
  end

  # TODO: we should validate this a bit harder. Phoenix will prevent
  # us from sending the user to an external URL, but it'll do so by
  # means of a 500 error.
  defp go_path(conn, %{go: nil}), do: Routes.live_path(conn, HomeLive)
  defp go_path(_conn, %{go: go}), do: go

end
