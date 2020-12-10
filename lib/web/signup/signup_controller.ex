defmodule Bonfire.Me.Web.SignupController do
  use Bonfire.Web, :controller
  alias Bonfire.Me.Identity.Accounts
  alias Bonfire.Me.Web.SignupLive

  def index(conn, _), do: live_render_with_conn(conn, SignupLive)

  def create(conn, params) do
    case Accounts.signup(Map.get(params, "signup_fields", %{})) do
      {:ok, _account} ->
        conn
        |> assign(:registered, true)
        |> live_render_with_conn(SignupLive)
      {:error, :taken} ->
        conn
        |> assign(:error, :taken)
        |> live_render_with_conn(SignupLive)
      {:error, changeset} ->
        IO.inspect(changeset)
        conn
        |> assign(:form, changeset)
        |> live_render_with_conn(SignupLive)
    end
  end

end
