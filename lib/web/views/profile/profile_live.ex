defmodule Bonfire.Me.Web.ProfileLive do
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

      following = if current_user && user && module_enabled?(Bonfire.Social.Follows) && Bonfire.Social.Follows.following?(current_user, user), do: [user.id]

      page_title = if e(current_user, :character, :username, "") == e(user, :character, :username, ""), do: "Your profile", else: e(user, :profile, :name, "Someone") <> "'s profile"

      smart_input_placeholder = if e(current_user, :character, :username, "") == e(user, :character, :username, ""), do: "Write something public...", else: "Write something for " <> e(user, :profile, :name, "this person")

      smart_input_text = if e(current_user, :character, :username, "") == e(user, :character, :username, ""), do:
      "", else: "@"<>e(user, :character, :username, "")<>" "

      search_placeholder = if e(current_user, :character, :username, "") == e(user, :character, :username, ""), do: "Search my profile", else: "Search " <> e(user, :profile, :name, "this person") <> "'s profile"

      {:ok,
        socket
        |> assign(
          page: "profile",
          page_title: page_title,
          selected_tab: "timeline",
          smart_input: true,
          has_private_tab: true,
          smart_input_placeholder: smart_input_placeholder,
          smart_input_text: smart_input_text,
          search_placholder: search_placeholder,
          feed_title: "User timeline",
          current_account: Map.get(socket.assigns, :current_account),
          current_user: current_user,
          user: user, # the user to display
          following: following || []
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

  def do_handle_params(%{"tab" => "posts" = tab} = _params, _url, socket) do
    current_user = e(socket.assigns, :current_user, nil)

    feed = if module_enabled?(Bonfire.Social.Posts), do: Bonfire.Social.Posts.list_by(e(socket.assigns, :user, :id, nil), current_user) #|> IO.inspect

    {:noreply,
     assign(socket,
       selected_tab: tab,
       feed: e(feed, :entries, []),
       smart_input_private: false,
       page_info: e(feed, :metadata, [])
     )}
  end

  def do_handle_params(%{"tab" => "boosts" = tab} = _params, _url, socket) do
    current_user = e(socket.assigns, :current_user, nil)

    feed = if module_enabled?(Bonfire.Social.Boosts), do: Bonfire.Social.Boosts.list_by(e(socket.assigns, :user, :id, nil), current_user) #|> IO.inspect

    {:noreply,
      assign(socket,
        selected_tab: tab,
        smart_input_private: false,
        feed: e(feed, :entries, []),
        page_info: e(feed, :metadata, [])
      )}
  end

  def do_handle_params(%{"tab" => "timeline" = _tab} = _params, _url, socket) do

    do_handle_params(%{}, nil, socket)
  end

  def do_handle_params(%{"tab" => "private" =tab} = _params, _url, socket) do
    IO.inspect(tab: tab)
    current_user = e(socket.assigns, :current_user, nil)

    smart_input_placeholder = if e(socket, :assigns, :current_user, :character, :username, "") == e(socket, :assigns, :user, :character, :username, ""), do: "Write a private note to self...", else: "Write a private message for " <> e(socket, :assigns, :user, :profile, :name, "this person")

    feed = if current_user, do: if module_enabled?(Bonfire.Social.Messages), do: Bonfire.Social.Messages.list(current_user, e(socket.assigns, :user, :id, nil)) #|> IO.inspect

    {:noreply,
     assign(socket,
       selected_tab: tab,
       feed: e(feed, :entries, []),
       smart_input_placeholder: smart_input_placeholder,
       smart_input_private: true
     )}
  end

  def do_handle_params(%{"tab" => tab} = _params, _url, socket) do
    IO.inspect(tab: tab)

    smart_input_placeholder = if e(socket, :assigns, :current_user, :character, :username, "") == e(socket, :assigns, :user, :character, :username, ""), do: "Write something public...", else: "Write something for " <> e(socket, :assigns, :user, :profile, :name, "this person")

    {:noreply,
     assign(socket,
       selected_tab: tab,
       smart_input_private: false,
       smart_input_placeholder: smart_input_placeholder
     )}
  end

  def do_handle_params(%{} = _params, _url, socket) do
    IO.inspect(tab: "default")

    current_user = e(socket.assigns, :current_user, nil)

     # feed = if user, do: Bonfire.Social.Activities.by_user(user)
     feed_id = e(socket.assigns, :user, :id, nil)
     feed = if feed_id && module_enabled?(Bonfire.Social.FeedActivities), do: Bonfire.Social.FeedActivities.feed(feed_id, socket)
     #IO.inspect(feed: feed)

    {:noreply,
     assign(socket,
     selected_tab: "timeline",
     smart_input_private: false,
     feed: e(feed, :entries, []),
     page_info: e(feed, :metadata, [])
     )}
  end

  def handle_params(params, uri, socket) do
    undead_params(socket, fn ->
      do_handle_params(params, uri, socket)
    end)
  end

  def handle_event(action, attrs, socket), do: Bonfire.Web.LiveHandler.handle_event(action, attrs, socket, __MODULE__)
  def handle_info(info, socket), do: Bonfire.Web.LiveHandler.handle_info(info, socket, __MODULE__)

end
