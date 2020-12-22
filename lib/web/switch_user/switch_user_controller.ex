defmodule Bonfire.Me.Web.SwitchUserController do

  use Bonfire.Web, :controller
  alias Bonfire.Me.Identity.{Accounts, Users}

  def index(conn, _) do
    case Users.by_account(Accounts.get_session(conn)) do
      [] -> no_users(conn)
      users ->
        conn
        |> assign(:current_account_users, users)
        |> live_render(UsersLive)
    end
  end

  def show(conn, %{"id" => username}) do
    show(Accounts.get_session(conn), username, conn)
  end

  defp show(nil, _username, conn), do: not_logged_in(conn)
  defp show(account_id, username, conn), do: lookup(account_id, username, conn)

  defp lookup(account_id, username, conn),
    do: lookup(Users.for_switch_user(username, account_id), conn)

  defp lookup({:ok, user}, conn), do: switch(conn, user)
  defp lookup({:error, :not_found}, conn), do: not_found(conn)
  defp lookup({:error, :not_permitted}, conn), do: not_permitted(conn)

  defp go_back(conn) do
    
  end

  defp switch(conn, user) do
    username = user.character.username
    conn
    |> put_session(:user_id, user.id)
    |> put_flash(:info, "Welcome back, @#{username}!")
    |> redirect(to: "/~@#{username}")
   end

  defp no_users(conn) do
    conn
    |> put_flash(:info, "Hey there! Let's fill out your profile!")
    |> redirect(to: "/~/create-user")
  end

  defp not_logged_in(conn) do
    conn
    |> put_flash(:error, "You must log in to switch user.")
    |> redirect(to: "/login")
  end

  defp not_found(conn) do
    conn
    |> put_flash(:error, "This username does not exist.")
    |> redirect(to: "/~")
  end

  defp not_permitted(conn) do
    conn
    |> put_flash(:error, "You are not permitted to switch to this user.")
    |> redirect(to: "/~")
  end

end
