defmodule Bonfire.Me.Web.ConfirmEmailController do

  use Bonfire.Web, :controller
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Web.ConfirmEmailLive

  def index(conn, _), do: live_render(conn, ConfirmEmailLive)

  def show(conn, %{"id" => token}) do
    case Accounts.confirm_email(token) do
      {:ok, account} ->
        confirmed(conn, account)
      {:error, "already_confirmed", _} ->
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
    case Accounts.request_confirm_email(form_cs(form)) do
      {:ok, _, _} ->
        conn
        |> assign(:requested, true)
        |> live_render(ConfirmEmailLive)
      {:error, "already_confirmed"} ->
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

  defp form_cs(params \\ %{}), do: Accounts.changeset(:confirm_email, params)

  defp confirmed(conn, account) do
    conn
    |> put_session(:account_id, account.id)
    |> put_flash(:info, l "Welcome back! Thanks for confirming your email address. You can now create a user profile.")
    |> redirect(to: path(:create_user))
  end

  defp already_confirmed(conn) do
    conn
    |> put_flash(:error, l "You've already confirmed your email address. You can log in now.")
    |> redirect(to: path(:login))
  end
end
