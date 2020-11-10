defmodule Bonfire.Me.Web.SignupController do
  use Bonfire.WebPhoenix, [:controller]
  alias Bonfire.Me.Accounts

  plug Bonfire.Me.Web.Plugs.MustBeGuest

  def index(conn, _) do
    if get_session(conn, :account_id),
      do: redirect(conn, to: "/home"),
      else: render(conn, "form.html", registered: false, error: nil, form: form())
  end

  def create(conn, params) do
    if get_session(conn, :account_id) do
      redirect(conn, to: "/home")
    else
       if Kernel.function_exported?(Accounts, :signup, 1) do
        case Accounts.signup(Map.get(params, "signup_fields", %{})) do
          {:ok, _account} ->
            render(conn, "form.html", registered: true)
          {:error, :taken} ->
            render(conn, "form.html", registered: false, error: :taken, form: form())
          {:error, changeset} ->
            render(conn, "form.html", registered: false, error: nil, form: changeset)
        end
      else
        render(conn, "form.html", registered: true)
      end
    end
  end

  defp form(params \\ %{}), do: Accounts.changeset(:signup, params)

end
