defmodule Bonfire.Me.Web.SignupController do
  use Bonfire.Web, :controller
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Web.SignupLive

  def index(conn, _), do: live_render(conn, SignupLive)

  def create(conn, params) do
    submitted = Map.get(params, "account", %{})
    # attrs = %{credential: submitted, email: submitted}
    case Accounts.signup(submitted) do
      {:ok, _account} ->
        conn
        |> assign(:registered, true)
        |> live_render(SignupLive)
      {:error, :taken} ->
        conn
        |> assign(:error, :taken)
        |> live_render(SignupLive)
      {:error, changeset} ->
        conn
        |> assign(:form, changeset)
        |> assign(:error, Bonfire.Repo.ChangesetErrors.changeset_errors_string(changeset, false))
        |> live_render(SignupLive)
    end
  end



end
