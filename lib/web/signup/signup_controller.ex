defmodule Bonfire.Me.Web.SignupController do
  use Phoenix.Controller, :controller
  alias Bonfire.Me.Accounts

  def index(conn, _) do
    if get_session(conn, :account_id),
      do: redirect(conn, to: "/_"),
      else: render(conn, "form.html", current_account: nil, registered: false, error: nil, form: form())
  end

  def create(conn, params) do
    if get_session(conn, :account_id) do
      redirect(conn, to: "/home")
    else
      case Accounts.signup(Map.get(params, "signup_form", %{})) do
        {:ok, _account} ->
          render(conn, "form.html", current_account: nil, registered: true)
        {:error, :taken} ->
          render(conn, "form.html", current_account: nil, registered: false, error: :taken, form: form())
        {:error, changeset} ->
          render(conn, "form.html", current_account: nil, registered: false, error: nil, form: changeset)
      end
    end
  end

  defp form(params \\ %{}), do: Accounts.changeset(:signup, params)

end
