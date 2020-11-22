defmodule Bonfire.Me.Web.LoginController do

  use Phoenix.Controller, namespace: Bonfire.Web
  import Plug.Conn
  import Bonfire.Common.Web.Gettext
  alias Bonfire.Web.Router.Helpers, as: Routes
  alias Bonfire.Web.Plugs.{MustBeGuest, MustLogIn}
  import Phoenix.LiveView.Controller
  import Bonfire.Common.Utils
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Web.LoginLive

  def index(conn, _) do
    if get_session(conn, :account_id),
      do: redirect(conn, to: "/~"),
      else: live_render(conn, LoginLive)
  end

  def create(conn, params) do
    form = Map.get(params, "login_fields", %{})
    case Accounts.login(Accounts.changeset(:login, form)) do
      {:ok, account} ->
        IO.inspect(ok: account)
        logged_in(account, conn)
      {:error, error} when is_atom(error) ->
        IO.inspect(error: error)
        conn
        |> assign(:error, error)
        |> live_render(LoginLive)
      {:error, changeset} ->
        IO.inspect(error: changeset)
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
