defmodule Bonfire.Me.Web.LoginController do

  use Bonfire.Web, :controller
  alias Bonfire.Me.Identity.Accounts
  alias Bonfire.Me.Web.LoginLive

  def index(conn, _), do: live_render(conn, LoginLive)

  def create(conn, params) do
    form = Map.get(params, "login_fields", %{})
    case Accounts.login(Accounts.changeset(:login, form)) do
      {:ok, account} ->
        logged_in(account, conn)
      {:error, error} when is_atom(error) ->
        conn
        |> assign(:error, error)
        |> live_render(LoginLive)
      {:error, changeset} ->
        conn
        |> assign(:form, changeset)
        |> live_render(LoginLive)
    end
  end

  defp form(params \\ %{}), do: Accounts.changeset(:login, params)

  defp logged_in(account, conn) do
    conn
    |> put_session(:account_id, account.id)
    |> put_flash(:info, "Welcome back!")
    |> redirect(to: "/~")
  end

end
