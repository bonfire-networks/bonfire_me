defmodule Bonfire.Me.Web.CreateUserController do

  use Bonfire.Web, :controller
  alias Bonfire.Me.Users
  alias Bonfire.Me.Web.{CreateUserLive, LoggedDashboardLive}

  def index(conn, _) do # GET only supports 'go'
    conn = fetch_query_params(conn)
    params = Map.take(conn.query_params, [:go, "go"])
    paint(conn, Users.changeset(:create, params, e(conn.assigns, :current_account, nil)))
  end

  def create(conn, params) do
    form = Map.get(params, "user", %{})
    changeset = Users.changeset(:create, form, e(conn.assigns, :current_account, nil))
    case Users.create(changeset, e(conn.assigns, :current_account, nil)) do
      {:ok, %{id: id, profile: %{name: name}} = _user} ->
        greet(conn, params, id, name)
      {:ok, %{id: id, character: %{username: username}} = _user} ->
        greet(conn, params, id, username)
      {:error, changeset} ->
        # IO.inspect(changeset_error: changeset)
        err = Bonfire.Repo.ChangesetErrors.changeset_errors_string(changeset, false) #|> IO.inspect
        conn
        |> assign(:error, err)
        |> put_flash(:error, "Please double check your inputs... "<>err)
        |> paint(changeset)
      r ->
        IO.inspect(create_user: r)
        conn
        |> put_flash(:error, "An unexpected error occured... ")
        |> paint(changeset)
    end
  end

  defp greet(conn, params, id, name) do
    conn
    |> put_session(:user_id, id)
    |> put_flash(:info, "Hey #{name}, nice to meet you!")
    |> redirect(to: go_where?(conn, params, path(LoggedDashboardLive)))
  end

  defp paint(conn, changeset) do
    conn
    |> assign(:form, changeset)
    |> live_render(CreateUserLive)
  end

end
