defmodule Bonfire.Me.Web.LoginController do

  use Bonfire.Web, :controller
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Web.LoginLive
  alias Bonfire.Common.Utils

  def index(conn, _) do # GET only supports 'go'
    conn = fetch_query_params(conn)
    paint(conn, form_cs(Map.take(conn.query_params, [:go, "go"])))
  end

  def create(conn, params) do
    params = Map.get(params, "login_fields", %{})
    form = Accounts.changeset(:login, params)
    case Accounts.login(form) do
      {:ok, account, user} -> logged_in(account, user, conn, form)
      {:error, changeset} -> paint(conn, changeset)
    end
  end

  defp form_cs(params \\ %{}), do: Accounts.changeset(:login, params)

  # the user logged in via email. if they only have one user in the
  # account, we can still log them directly into it, otherwise we must
  # show them the user switcher.
  defp logged_in(account, nil, conn, form) do
    case Users.get_only_in_account(account) do
      {:ok, user} -> logged_in(account, user, conn, form)
      :error ->
        conn
        |> put_session(:account_id, account.id)
        |> put_session(:user_id, nil)
        |> put_flash(:info, l "Welcome back!")
        |> redirect(to: go_where?(conn, form, path(:switch_user)))
    end
  end

  # the user logged in via username, or they logged in via email and
  # we found there was only one user in the account, so we're going to
  # just send them straight to the homepage and avoid the user
  # switcher.
  defp logged_in(account, user, conn, form) do
    conn
    |> put_session(:account_id, account.id)
    |> put_session(:user_id, user.id)
    |> put_flash(:info, l "Welcome back, #{user.character.username}!")
    |> redirect(to: go_where?(conn, form, path(:home)))
  end

  defp paint(conn, changeset) do
    conn
    |> assign(:form, changeset)
    |> live_render(LoginLive)
  end

end
