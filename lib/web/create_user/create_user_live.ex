defmodule Bonfire.Me.Web.CreateUserLive do
  use Bonfire.Web, :live_view
  alias CommonsPub.Users.User
  alias Bonfire.Me.Users
  alias Bonfire.Me.Accounts
  alias Bonfire.Common.Web.LivePlugs

  def mount(params, session, socket) do
    LivePlugs.live_plug params, session, socket, [
      LivePlugs.LoadSessionAuth,
      LivePlugs.StaticChanged,
      LivePlugs.Csrf,
      &mounted/3,
    ]
  end

  defp mounted(params, _sessions, socket) do
    {:ok,
     socket
     |> assign(form: form(%{account_id: socket.assigns["account_id"]}))}
  end

  def handle_event("submit", params, socket) do
    {:noreply, socket}
  end

  # def create(conn, params) do
  #   account = Accounts.get_for_session(conn)
  #   Map.get(params, "create_user_fields",  Map.get(params, "user", %{}))
  #   |> Users.create(account)
  #   |> case do
  #     {:ok, user} -> switched(conn, user)
  #     {:error, form} ->
  #        render(conn, "form.html", form: form, current_account: account)
  #   end
  # end

  defp form(attrs \\ %{}, account), do: Users.changeset(:create, attrs, account)

  # defp switched(conn, %User{id: id, character: %{username: username}}) do
  #   conn
  #   |> put_flash(:info, "Welcome, #{username}, you're all ready to go!")
  #   |> put_session(:user_id, id)
  #   |> redirect(to: "/~/@#{username}")
  # end


end
