defmodule Bonfire.Me.Web.CreateUserController do

  use Bonfire.Web, :controller
  alias Bonfire.Me.Users
  alias Bonfire.Me.Web.CreateUserLive

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
        debug(changeset_error: changeset)
        err = EctoSparkles.Changesets.Errors.changeset_errors_string(changeset, false) #|> IO.inspect
        conn
        |> assign(:error, err)
        |> put_flash(:error, l("Please double check your inputs... ")<>err)
        |> paint(changeset)
      r ->
        debug(create_user: r)
        conn
        |> put_flash(:error, l "An unexpected error occured... ")
        |> paint(changeset)
    end
  end

  defp greet(conn, params, id, name) do
    conn
    |> put_session(:user_id, id)
    |> put_flash(:info, l("Hey %{name}, nice to meet you!", name: name))
    |> redirect(go_where?(conn, params, path(:home)))
  end

  defp paint(conn, changeset) do
    conn
    |> assign(:form, changeset)
    |> live_render(CreateUserLive)
  end

end
