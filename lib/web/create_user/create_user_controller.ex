defmodule Bonfire.Me.Web.CreateUserController do
  use Bonfire.WebPhoenix, [:controller]
  alias CommonsPub.Users.User
  alias Bonfire.Me.Users

  plug Bonfire.Me.Web.Plugs.MustLogIn, load_account: true

  def index(conn, _),
    do: render(conn, "form.html", form: form(conn.assigns[:account]))

  def create(conn, params) do
    if Kernel.function_exported?(Users, :create, 1) do
      Map.get(params, "user_fields", %{})
      |> Users.create(conn.assigns[:account])
      |> case do
        {:ok, user} -> switched(conn, user)
        {:error, form} ->
          render(conn, "form.html", form: form)
      end
    else
      switched(conn, %{character: %{username: "fake"}} )
    end
  end

  defp form(attrs \\ %{}, account), do: Users.changeset(:create, attrs, account)

  defp switched(conn, %{id: _id, character: %{username: username}}) do
    conn
    |> put_flash(:info, "Welcome, #{username}, you're all ready to go!")
    |> put_session(:username, username)
    |> redirect(to: "/home/@#{username}")
  end

end
