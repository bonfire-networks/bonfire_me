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

      "@"<>username ->
        get_user(username)
      username ->
        get_user(username)
    end
    # IO.inspect(user: user)

    if user do

      # following = if current_user && current_user.id != user.id && module_enabled?(Bonfire.Social.Follows) && Bonfire.Social.Follows.following?(current_user, user), do: [user.id] |> IO.inspect(label: "following")

      page_title = if e(current_user, :character, :username, "") == e(user, :character, :username, ""), do: l( "Your profile"), else: e(user, :profile, :name, l "Someone") <> "'s profile"

      smart_input_placeholder = if e(current_user, :character, :username, "") == e(user, :character, :username, ""), do: l( "Write something public..."), else: l("Write something for ") <> e(user, :profile, :name, l("this person"))

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
          search_placholder: search_placeholder,
          feed_title: l( "User timeline"),
          user: user, # the user to display
        )
      |> assign_global(
        # following: following || [],
        smart_input_placeholder: smart_input_placeholder,
        smart_input_text: smart_input_text,
        to_circles: [{e(user, :profile, :name, e(user, :character, :username, l "someone")), e(user, :id, nil)}]
      )}
    else
      {:ok,
        socket
        |> put_flash(:error, l "Profile not found")
        |> push_redirect(to: "/error")
      }
    end
  end

  def get_user(username) do
    with {:ok, user} <- Bonfire.Me.Users.by_username(username) do
      user
    else _ ->
       with {:ok, character} <- Bonfire.Me.Characters.by_username(username) do
        Bonfire.Common.Pointers.get!(character.id) # FIXME? this results in extra queries
      else _ ->
        nil
      end
    end
  end

  def do_handle_params(%{"tab" => "posts" = tab} = _params, _url, socket) do
    current_user = current_user(socket)

    feed = if module_enabled?(Bonfire.Social.Posts), do: Bonfire.Social.Posts.list_by(e(socket.assigns, :user, :id, nil), current_user) #|> IO.inspect

    {:noreply,
     assign(socket,
       selected_tab: tab,
       feed: e(feed, :entries, []),
       page_info: e(feed, :metadata, [])
     )}
  end

  def do_handle_params(%{"tab" => "boosts" = tab} = _params, _url, socket) do
    current_user = current_user(socket)

    feed = if module_enabled?(Bonfire.Social.Boosts), do: Bonfire.Social.Boosts.list_by(e(socket.assigns, :user, :id, nil), current_user) #|> IO.inspect

    {:noreply,
      assign(socket,
        selected_tab: tab,
        feed: e(feed, :entries, []),
        page_info: e(feed, :metadata, [])
      )}
  end

  def do_handle_params(%{"tab" => "timeline" = _tab} = _params, _url, socket) do

    do_handle_params(%{}, nil, socket)
  end

  def do_handle_params(%{"tab" => "private" =tab} = _params, _url, socket) do
    current_user = current_user(socket)
    user = e(socket, :assigns, :user, nil)

    smart_input_placeholder = if e(current_user, :character, :username, "") == e(user, :character, :username, ""), do: l( "Write a private note to self..."), else: l("Write a private message for ") <> e(user, :profile, :name, l "this person")

    smart_input_text = if e(current_user, :character, :username, "") == e(user, :character, :username, ""),
    do: "",
    else: "@"<>e(user, :character, :username, "")<>" "

    feed = if current_user, do: if module_enabled?(Bonfire.Social.Messages), do: Bonfire.Social.Messages.list(current_user, user) #|> IO.inspect(label: "messages")

    {:noreply,
     assign(socket,
       selected_tab: tab,
       feed: e(feed, :entries, []),
     )
    |> assign_global(
      smart_input_placeholder: smart_input_placeholder,
      smart_input_text: smart_input_text,
      to_circles: [{e(user, :profile, :name, e(user, :character, :username, l "someone")), e(user, :id, nil)}],
      create_activity_type: "message"
    )
    }
  end


  def do_handle_params(%{"tab" => "followers" =tab} = _params, _url, socket) do
    followers = Bonfire.Social.Follows.list_followers(e(socket, :assigns, :user, nil), current_user(socket)) |> IO.inspect(label: tab)

    {:noreply,
    assign(socket,
      selected_tab: tab,
      followers: e(followers, :entries, []),
      page_info: e(followers, :metadata, [])
    )}
  end


  def do_handle_params(%{"tab" => "followed" =tab} = _params, _url, socket) do
    followed = Bonfire.Social.Follows.list_followed(e(socket, :assigns, :user, nil), current_user(socket)) |> IO.inspect(label: tab)

    {:noreply,
    assign(socket,
      selected_tab: tab,
      followed: e(followed, :entries, []),
      page_info: e(followed, :metadata, [])
    )}
  end


  def do_handle_params(%{"tab" => tab} = _params, _url, socket) do

    smart_input_placeholder = if e(socket, :assigns, :current_user, :character, :username, "") == e(socket, :assigns, :user, :character, :username, ""), do: l( "Write something public..."), else: l("Write something for ") <> e(socket, :assigns, :user, :profile, :name, l "this person")

    {:noreply,
     assign(socket,
       selected_tab: tab,
       smart_input_placeholder: smart_input_placeholder
     )}
  end

  def do_handle_params(%{} = _params, _url, socket) do

    current_user = current_user(socket)

     # feed = if user, do: Bonfire.Social.Activities.by_user(user)
     feed_id = e(socket.assigns, :user, :id, nil)
     feed = if feed_id && module_enabled?(Bonfire.Social.FeedActivities), do: Bonfire.Social.FeedActivities.feed(feed_id, socket)
     #IO.inspect(feed: feed)

    {:noreply,
     assign(socket,
     selected_tab: "timeline",
     feed: e(feed, :entries, []),
     page_info: e(feed, :metadata, [])
     )}
  end

  def handle_params(params, uri, socket) do
    undead_params(socket, fn ->
      do_handle_params(params, uri, socket)
    end)
  end

  def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  def handle_info(info, socket), do: Bonfire.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

end
