defmodule Bonfire.Me.Web.CreateUserController do
  use Bonfire.Web, :controller
  alias CommonsPub.Users.User
  alias Bonfire.Me.Web.Plugs.MustLogIn
  alias Bonfire.Me.Users
  alias Bonfire.Me.Accounts

  def index(conn, _) do
    account = Accounts.get_for_session(conn)
    render(conn, "form.html", form: form(account), current_account: account)
  end


  def create(conn, params) do
    account = Accounts.get_for_session(conn)
    IO.inspect(params)
    Map.get(params, "create_user_fields",  Map.get(params, "user", %{}))
    |> Users.create(account)
    |> case do
      {:ok, user} -> switched(conn, user)
      {:error, form} ->
         render(conn, "form.html", form: form, current_account: account)
    end
  end

  defp form(attrs \\ %{}, account), do: Users.changeset(:create, attrs, account)

  defp switched(conn, %User{id: id, character: %{username: username}}) do
    conn
    |> put_flash(:info, "Welcome, #{username}, you're all ready to go!")
    |> put_session(:user_id, id)
    |> redirect(to: "/~/@#{username}")
  end


end
