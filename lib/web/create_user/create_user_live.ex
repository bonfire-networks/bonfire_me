defmodule Bonfire.Me.Web.CreateUserLive do
  use Bonfire.Web, :live_view
  alias Bonfire.Data.Identity.User
  alias Bonfire.Me.Identity.{Accounts, Users}
  alias Bonfire.Common.Web.LivePlugs
  alias Bonfire.Me.Web.{CreateUserLive, MeHomeLive}

  def mount(params, session, socket) do
    LivePlugs.live_plug params, session, socket, [
      LivePlugs.StaticChanged,
      LivePlugs.Csrf,
      &mounted/3,
    ]
  end

  defp mounted(_params, session, socket) do
    {:ok,
     socket
     |> assign_new(:current_user, fn -> nil end)
     |> assign(form: form(socket.assigns[:current_account]))}
  end

  def handle_event("validate", %{"user" => params}, socket) do
    form =
      Users.changeset(:create, params, socket.assigns[:current_account])
      |> Map.put(:action, :insert)
    {:noreply, assign(socket, form: form)}
  end
  def handle_event("submit", %{"user" => params}, socket) do
    case Users.create(params, socket.assigns()[:current_account]) do
      {:ok, user} -> {:noreply, switched(socket, user)}
      {:error, form} -> {:noreply, assign(socket, form: form)}
    end
  end

  defp form(attrs \\ %{}, account), do: Users.changeset(:create, attrs, account)

  defp switched(socket, %{character: %{username: username}}) do
    socket
    |> put_flash(:info, "Welcome, @#{username}, you're all ready to go!")
    |> push_redirect(to: Routes.live_path(socket, MeHomeLive, username))
  end


end
