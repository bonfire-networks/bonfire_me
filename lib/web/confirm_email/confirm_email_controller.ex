defmodule Bonfire.Me.Web.ConfirmEmailController do

  use Bonfire.Web, :controller
  alias Bonfire.Me.Identity.Accounts
  alias Bonfire.Me.Web.ConfirmEmailLive

  def index(conn, _), do: live_render(conn, ConfirmEmailLive)

  def show(conn, %{"id" => token}) do
    case Accounts.confirm_email(token) do
      {:ok, account} ->
        confirmed(conn, account)
      {:error, :confirmed, _} ->
        already_confirmed(conn)
      {:error, :expired, _} ->
        conn
        |> assign(:error, :expired_link)
        |> live_render(ConfirmEmailLive)
      _ ->
        conn
        |> assign(:error, :not_found)
        |> live_render(ConfirmEmailLive)
    end
  end

  def create(conn, params) do
    form = Map.get(params, "confirm_email_fields", %{})
    case Accounts.request_confirm_email(form(form)) do
      {:ok, _, _} ->
        conn
        |> assign(:requested, true)
        |> live_render(ConfirmEmailLive)
      {:error, :confirmed} ->
        already_confirmed(conn)
      {:error, :not_found} ->
        conn
        |> assign(:error, :not_found)
        |> live_render(ConfirmEmailLive)
      {:error, changeset} ->
        conn
        |> assign(:form, changeset)
        |> live_render(ConfirmEmailLive)
    end
  end

  defp form(params \\ %{}), do: Accounts.changeset(:confirm_email, params)

  defp confirmed(conn, account) do
    conn
    |> put_session(:account_id, account.id)
    |> put_flash(:info, "Welcome back! Thanks for confirming your email address.")
    |> redirect(to: Routes.live_path(conn, Bonfire.Me.Web.LoggedDashboardLive))
  end

  defp already_confirmed(conn) do
    conn
    |> put_flash(:info, "You've already confirmed your email address. You can log in now.")
    |> redirect(to: Routes.login_path(conn))
  end
end
