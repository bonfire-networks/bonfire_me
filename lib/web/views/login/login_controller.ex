defmodule Bonfire.Me.Web.LoginController do

  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Users
  alias Bonfire.Me.Web.LoginLive
  alias Bonfire.Common.Utils
  import Where

  def index(conn, _) do # GET only supports 'go'
    conn = fetch_query_params(conn)
    paint(conn, form_cs(Map.take(conn.query_params, [:go, "go"])))
  end

  def create(conn, form) do
    params = Map.get(form, "login_fields", form)
    cs = Accounts.changeset(:login, params)
    case Accounts.login(cs) do
      {:ok, account, user} -> logged_in(account, user, conn, form)
      {:error, changeset} -> paint(conn, changeset)
      _ ->
        error("LoginController: unhandled error")
        paint(conn, cs)
    end
  end

  defp form_cs(params \\ %{}), do: Accounts.changeset(:login, params)

  # the user logged in via email and have more than one user in the
  # account, so we must show them the user switcher.
  defp logged_in(account, nil, conn, form) do
    conn
      |> put_session(:account_id, account.id)
      |> put_session(:user_id, nil)
      |> put_flash(:info, l "Welcome back!")
      |> redirect(to: path(:switch_user) <> copy_go(form))
  end

  # the user logged in via username, or they logged in via email and
  # we found there was only one user in the account, so we're going to
  # just send them straight to the homepage and avoid the user
  # switcher.
  defp logged_in(account, user, conn, form) do
    conn
    |> put_session(:account_id, account.id)
    |> put_session(:user_id, user.id)
    |> put_flash(:info, l("Welcome back, %{name}", name: e(user, :profile, :name, e(user, :character, :username, "anonymous"))))
    |> redirect_to_previous_go(form, path(:feed))
  end

  defp paint(conn, changeset) do
    conn
    |> assign(:form, changeset)
    |> live_render(LoginLive)
  end

end
