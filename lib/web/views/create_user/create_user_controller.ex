defmodule Bonfire.Me.Web.CreateUserController do

  use Bonfire.Web, :controller
  alias Bonfire.Me.Users
  alias Bonfire.Me.Web.{CreateUserLive, LoggedDashboardLive}

  def index(conn, _) do # GET only supports 'go'
    conn = fetch_query_params(conn)
    params = Map.take(conn.query_params, [:go, "go"])
    paint(conn, Users.changeset(:create, params, conn.assigns.current_account))
  end

  def create(conn, params) do
    form = Map.get(params, "user", %{})
    changeset = Users.changeset(:create, form, conn.assigns.current_account)
    case Users.create(changeset, conn.assigns.current_account) do
      {:ok, user} ->
        #IO.inspect(user: user)
        conn
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Hey, #{user.character.username}, nice to meet you!")
        |> redirect(to: go_where?(conn, params, Routes.live_path(conn, LoggedDashboardLive)))
      {:error, changeset} ->
        # IO.inspect(changeset_error: changeset)
        err = Bonfire.Repo.ChangesetErrors.changeset_errors_string(changeset, false) #|> IO.inspect
        conn
        |> assign(:error, err)
        |> put_flash(:error, "Please double check your inputs... "<>err)
        |> paint(changeset)
    end
  end

  defp paint(conn, changeset) do
    conn
    |> assign(:form, changeset)
    |> live_render(CreateUserLive)
  end

end
