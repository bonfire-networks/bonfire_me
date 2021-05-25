defmodule Bonfire.Me.Web.PrivateLive do
  use Bonfire.Web, :live_view
  alias Bonfire.Me.Fake
  alias Bonfire.Web.LivePlugs

  def mount(params, session, socket) do
    LivePlugs.live_plug params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      LivePlugs.LoadCurrentUserCircles,
      LivePlugs.StaticChanged,
      LivePlugs.Csrf,
      &mounted/3
    ]
  end

  defp mounted(params, _session, socket) do

    current_user = e(socket.assigns, :current_user, nil)
    current_username = e(current_user, :character, :username, nil)

    user = case Map.get(params, "username") do
      nil ->
        current_user

      username when username == current_username ->
        current_user

      username ->
        with {:ok, user} <- Bonfire.Me.Users.by_username(username) do
          user
        else _ ->
          nil
        end
    end
    # IO.inspect(user: user)

    if user do

      smart_input_text = if e(current_user, :character, :username, "") == e(user, :character, :username, ""), do:
      "", else: "@"<>e(user, :character, :username, "")<>" "

      search_placeholder = if e(current_user, :character, :username, "") == e(user, :character, :username, ""), do: "Search my profile", else: "Search " <> e(user, :profile, :name, "this person") <> "'s profile"
      feed = if current_user, do: if module_enabled?(Bonfire.Social.Messages), do: Bonfire.Social.Messages.list(current_user, e(socket.assigns, :user, :id, nil)) #|> IO.inspect

      {:ok,
        socket
        |> assign(
          page: "private",
          feed: e(feed, :entries, []),
          page_title: "Direct Messages",
          smart_input: true,
          has_private_tab: true,
          smart_input_placeholder: "Note to self...",
          smart_input_text: smart_input_text,
          search_placholder: search_placeholder,
          feed_title: "User timeline",
          current_account: Map.get(socket.assigns, :current_account),
          current_user: current_user,
          user: user, # the user to display
          following: []
        )
      |> cast_self(to_circles: [{e(user, :profile, :name, e(user, :character, :username, "someone")), e(user, :id, nil)}])}
    else
      {:ok,
        socket
        |> put_flash(:error, "Profile not found")
        |> push_redirect(to: "/error")
      }
    end
  end


  def handle_event(action, attrs, socket), do: Bonfire.Web.LiveHandler.handle_event(action, attrs, socket, __MODULE__)
  def handle_info(info, socket), do: Bonfire.Web.LiveHandler.handle_info(info, socket, __MODULE__)

end
