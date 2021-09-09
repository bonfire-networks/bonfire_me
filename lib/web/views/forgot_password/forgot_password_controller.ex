defmodule Bonfire.Me.Web.ForgotPasswordController do
  use Bonfire.Web, :controller
  alias Bonfire.Me.Web.ForgotPasswordLive
  alias Bonfire.Me.Accounts

  def index(conn, %{"login_token" => login_token}) do
    case Accounts.confirm_email(login_token, confirm_action: :change_password) do
      {:ok, account} -> change_pw(conn, account)
      {:error, changeset} ->
        conn
        |> assign(:form, changeset)
        |> live_render(ForgotPasswordLive)
    end
  end

  def index(conn, _), do: live_render(conn, ForgotPasswordLive)

  def create(conn, params) do
    data = Map.get(params, "forgot_password_fields", %{})
    case Accounts.request_forgot_password(form(data)) do
      {:ok, _, _} ->
        conn
        |> assign(:requested, true)
        |> live_render(ForgotPasswordLive)
      {:error, :not_found} ->
        conn
        |> assign(:error, :not_found)
        |> live_render(ForgotPasswordLive)
      {:error, changeset} ->
        conn
        |> assign(:form, changeset)
        |> live_render(ForgotPasswordLive)
    end
  end

  def form(params \\ %{}), do: Accounts.changeset(:forgot_password, params)

  defp change_pw(conn, account) do
    conn
    |> put_session(:account_id, account.id)
    |> put_flash(:info, l "Welcome back! Thanks for confirming your email address. You can now change your password.")
    |> redirect(to: path(:dashboard))
    # |> redirect(to: path(Bonfire.Me.Web.ChangePasswordLive)) # TODO: switch to this once change password works
  end

end
