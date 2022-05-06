defmodule Bonfire.Me.Web.SignupController do
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Web.SignupLive

  def index(conn, params) do
    conn
    |> render_view(params)
  end

  def create(conn, params) do
    {account_attrs, params} = Map.pop(params, "account", %{})
    ret = Accounts.signup(account_attrs, invite: params["invite"]) |> debug()
    case ret do
      {:ok, %{email: %{confirmed_at: confirmed_at}}} when not is_nil(confirmed_at) ->
        conn
        |> assign(:registered, :confirmed)
        |> render_view(Map.put(params, "registered", :confirmed))
      {:ok, _account} ->
        conn
        |> assign(:registered, :check_email)
        |> render_view(Map.put(params, "registered", :check_email))
      {:error, :taken} ->
        conn
        |> assign(:error, :taken)
        |> render_view(params)
      {:error, changeset} ->
        conn
        |> assign(:form, changeset)
        |> assign(:error, EctoSparkles.Changesets.Errors.changeset_errors_string(changeset, false))
        |> render_view(params)
    end
  end

  def render_view(conn, params) do
    live_render(conn, SignupLive, session: params)
  end



end
