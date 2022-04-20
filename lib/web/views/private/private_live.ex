defmodule Bonfire.Me.Web.PrivateLive do
  use Bonfire.Web, {:surface_view, [layout: {Bonfire.UI.Social.Web.LayoutView, "without_sidebar.html"}]}
  alias Bonfire.Me.Fake
  alias Bonfire.Web.LivePlugs

  def mount(params, session, socket) do
    LivePlugs.live_plug params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      LivePlugs.UserRequired,
      LivePlugs.LoadCurrentUserCircles,
      LivePlugs.StaticChanged,
      LivePlugs.Csrf, LivePlugs.Locale,
      &mounted/3
    ]
  end

  defp mounted(params, _session, socket) do

    current_user = current_user(socket)
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
    # debug(user: user)

    if user do

      smart_input_text = if e(current_user, :character, :username, "") == e(user, :character, :username, ""), do:
      "", else: "@"<>e(user, :character, :username, "")<>" "

      search_placeholder = if e(current_user, :character, :username, "") == e(user, :character, :username, ""), do: l ("Search my profile"), else: "Search " <> e(user, :profile, :name, "this person") <> "'s profile"

      feed = if current_user, do: if module_enabled?(Bonfire.Social.Messages), do: Bonfire.Social.Messages.list(current_user, ulid(e(socket.assigns, :user, nil))) #|> debug()

      {:ok,
        socket
        |> assign(
          page: "private",
          feed: e(feed, :edges, []),
          smart_input: true,
          tab_id: nil,
          has_private_tab: true,
          search_placholder: search_placeholder,
          feed_title: l("Messages"),
          user: user, # the user to display
        )
      |> assign_global(
        create_activity_type: :message,
        smart_input_prompt: l("Note to self..."),
        smart_input_text: smart_input_text,
        to_circles: [{e(user, :profile, :name, e(user, :character, :username, l "someone")), e(user, :id, nil)}]
        )
      }
    else
      {:ok,
        socket
        |> put_flash(:error, l "User not found")
        |> push_redirect(to: "/error")
      }
    end
  end

  def handle_params(params, url, socket), do: Bonfire.Common.LiveHandlers.handle_params(params, url, socket, __MODULE__)
  def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  def handle_info(info, socket), do: Bonfire.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

end
