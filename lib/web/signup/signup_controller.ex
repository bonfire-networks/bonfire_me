defmodule Bonfire.Me.Web.SignupController do
  use Bonfire.Web, :controller
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Web.SignupLive
  import Bonfire.Web.Hax

  @defaults [current_account: nil, registered: false, error: nil]

  def index(conn, _) do
    if get_session(conn, :account_id),
      do: redirect(conn, to: "/~"),
      else: render_live_view(conn, SignupLive, [form: form()] ++ @defaults)
  end
  
  def create(conn, params) do
    if get_session(conn, :account_id) do
      redirect(conn, to: "/home")
    else
      case Accounts.signup(Map.get(params, "signup_fields", %{})) do
        {:ok, _account} ->
          render_live_view conn, SignupLive,
            current_account: nil, registered: true
        {:error, :taken} ->
          render_live_view conn, SignupLive,
            current_account: nil, registered: false, error: :taken, form: form()
        {:error, changeset} ->
          render_live_view conn, SignupLive,
            current_account: nil, registered: false, error: nil, form: changeset)
      end
    end
  end

  defp form(params \\ %{}), do: Accounts.changeset(:signup, params)

end
