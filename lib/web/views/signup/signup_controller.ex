defmodule Bonfire.Me.Web.SignupController do
  use Bonfire.Web, :controller
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Web.SignupLive

  def index(conn, params) do
    conn
    |> render_view(params)
  end

  def create(conn, params) do
    {submitted, params} = Map.pop(params, "account", %{})
    # attrs = %{credential: submitted, email: submitted}
    case Accounts.signup(submitted, invite: params["invite"]) do
      {:ok, _account} ->
        conn
        |> assign(:registered, true)
        |> render_view(params)
      {:error, :taken} ->
        conn
        |> assign(:error, :taken)
        |> render_view(params)
      {:error, changeset} ->
        conn
        |> assign(:form, changeset)
        |> assign(:error, Bonfire.Repo.ChangesetErrors.changeset_errors_string(changeset, false))
        |> render_view(params)
    end
  end

  def render_view(conn, params) do
    live_render(conn, SignupLive, session: params)
  end



end
