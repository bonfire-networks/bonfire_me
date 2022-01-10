defmodule Bonfire.Me.Web.SwitchUserController do

  use Bonfire.Web, :controller
  alias Bonfire.Data.Identity.Account
  alias Bonfire.Me.Users
  alias Bonfire.Me.Web.{LoggedDashboardLive, SwitchUserLive}

  @doc "A listing of users in the account."
  def index(%{assigns: the}=conn, params) do
    conn = fetch_query_params(conn)
    index(the[:current_account_users], the[:current_account], conn, params)
  end

  defp index([], _, conn, params) do
    conn
    |> put_flash(:info, l "Hey there! Let's fill out your profile!")
    |> redirect(to: path(:create_user) <> copy_go(params))
  end

  defp index([_|_]=users, _, conn, _params) do
    conn
    |> assign(:current_account_users, users)
    |> assign(:go, go_query(conn))
    |> live_render(SwitchUserLive)
  end

  defp index(nil, %Account{}=account, conn, params),
    do: index(Users.by_account(account), account, conn, params)

  defp index(nil, _account, _conn, _params) do
    Logger.error("[SwitchUserController.index] Missing :current_account")
    throw :missing_current_account
  end

  @doc "Switch to a user, if permitted."
  def show(conn, %{"id" => username} = params) do
    show(Users.by_username_and_account(username, e(conn.assigns, :current_account, nil).id), conn, params)
  end

  defp show({:ok, user}, conn, params) do
    conn
    |> put_session(:user_id, user.id)
    |> put_flash(:info, l("Welcome back, %{name}!", name: greet(user)))
    |> redirect(to: go_where?(conn, params, path(:home)))
  end

  defp show({:error, _}, conn, params) do
    Logger.error("Wrong user")
    conn
    |> put_flash(:error, l "You can only identify as users in your account.")
    |> redirect(to: path(:switch_user) <> copy_go(params))
  end

  defp greet(%{profile: %{name: name}}) when is_binary(name) do
    name
  end
  defp greet(%{character: %{username: username}}) when is_binary(username) do
    "@#{username}"
  end
  defp greet(_) do
    "stranger"
  end


end
