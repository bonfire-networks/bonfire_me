defmodule Bonfire.Me.Web.ForgotPasswordController do
  use Bonfire.Web, :controller
  alias Bonfire.Me.Web.ForgotPasswordLive
  alias Bonfire.Me.Accounts

  def index(conn, _), do: live_render(conn, ForgotPasswordLive)

  def create(conn, params) do
    form = Map.get(params, "forgot_password_fields", %{})
    case Accounts.request_forgot_password(form(form)) do
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

end
