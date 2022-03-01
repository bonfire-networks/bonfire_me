defmodule Bonfire.Me.Web.ProfileLive do
  use Bonfire.Web, :surface_view
  import Bonfire.Me.Integration
  import Where

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

    # debug(user)

    if user do

      # following = if current_user && current_user.id != user.id && module_enabled?(Bonfire.Social.Follows) && Bonfire.Social.Follows.following?(current_user, user), do: [user.id] |> debug(label: "following")

      page_title = if current_username == e(user, :character, :username, ""), do: l( "Your profile"), else: e(user, :profile, :name, l "Someone") <> "'s profile"

      # smart_input_prompt = if current_username == e(user, :character, :username, ""), do: l( "Write something..."), else: l("Write something for ") <> e(user, :profile, :name, l("this person"))
      smart_input_prompt = ""
      smart_input_text = if current_username == e(user, :character, :username, ""), do:
      "", else: "@"<>e(user, :character, :username, "")<>" "

      search_placeholder = if current_username == e(user, :character, :username, ""), do: "Search my profile", else: "Search " <> e(user, :profile, :name, "this person") <> "'s profile"

      {:ok,
        socket
        |> assign(
          page: "profile",
          page_title: page_title,
          selected_tab: "timeline",
          smart_input: true,
          has_private_tab: true,
          feed_title: l( "User timeline"),
          user: user, # the user to display
          feed: [],
          page_info: []
        )
      |> assign_global(
        # following: following || [],
        search_placholder: search_placeholder,
        smart_input_prompt: smart_input_prompt,
        smart_input_text: smart_input_text,
        # to_circles: [{e(user, :profile, :name, e(user, :character, :username, l "someone")), e(user, :id, nil)}]
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
    else _ -> # handle other character types beyond User
       with {:ok, character} <- Bonfire.Me.Characters.by_username(username) do
        Bonfire.Common.Pointers.get!(character.id) # FIXME? this results in extra queries
      else _ ->
        nil
      end
    end
  end

  def do_handle_params(%{"tab" => "posts" = tab} = _params, _url, socket) do
    user = e(socket, :assigns, :user, nil)

    feed = if module_enabled?(Bonfire.Social.Posts), do: Bonfire.Social.Posts.list_by(user, socket) #|> IO.inspect

    {:noreply,
     assign(socket,
       selected_tab: tab,
       feed: e(feed, :edges, []),
       page_info: e(feed, :page_info, [])
     )}
  end

  def do_handle_params(%{"tab" => "boosts" = tab} = _params, _url, socket) do
    user = e(socket, :assigns, :user, nil)

    feed = if module_enabled?(Bonfire.Social.Boosts), do: Bonfire.Social.Boosts.list_by(user, socket) #|> debug("boosts")

    {:noreply,
      assign(socket,
        selected_tab: tab,
        feed: e(feed, :edges, []),
        page_info: e(feed, :page_info, [])
      )}
  end

  def do_handle_params(%{"tab" => "timeline" = tab} = _params, _url, socket) do

    user = e(socket, :assigns, :user, nil)

    feed_id = if user && module_enabled?(Bonfire.Social.Feeds), do: Bonfire.Social.Feeds.feed_id(:outbox, user)
    feed = if feed_id && module_enabled?(Bonfire.Social.FeedActivities), do: Bonfire.Social.FeedActivities.feed(feed_id, socket)
  #  debug(feed: feed)

  {:noreply,
    assign(socket,
    selected_tab: tab,
    feed_id: feed_id,
    feed: e(feed, :edges, []),
    page_info: e(feed, :page_info, [])
    )}
  end

  def do_handle_params(%{"tab" => "private" =tab} = _params, _url, socket) do
    current_user = current_user(socket)
    user = e(socket, :assigns, :user, nil)

    page_title = if e(current_user, :character, :username, "") == e(user, :character, :username, ""), do: l( "My messages"), else: l("Messages with")<>" "<>e(user, :profile, :name, l "someone")

    # smart_input_prompt = if e(current_user, :character, :username, "") == e(user, :character, :username, ""), do: l( "Write a private note to self..."), else: l("Write a private message for ") <> e(user, :profile, :name, l "this person")
    smart_input_prompt = ""
    smart_input_text = if e(current_user, :character, :username, nil) != e(user, :character, :username, nil),
    do: "@"<>e(user, :character, :username, "")<>" ",
    else: ""

    feed = if current_user, do: if module_enabled?(Bonfire.Social.Messages), do: Bonfire.Social.Messages.list(current_user, user) #|> debug(label: "messages")

    {:noreply,
     assign(socket,
       selected_tab: tab,
       feed: e(feed, :edges, []),
     )
    |> assign_global(
      page_title: page_title,
      smart_input_prompt: smart_input_prompt,
      smart_input_text: smart_input_text,
      to_circles: [{e(user, :profile, :name, e(user, :character, :username, l "someone")), e(user, :id, nil)}],
      create_activity_type: :message
    )
    }
  end


  def do_handle_params(%{"tab" => "followers" =tab} = _params, _url, socket) do
    user = e(socket, :assigns, :user, nil)
    followers = Bonfire.Social.Follows.list_followers(user, socket) |> debug("followers")

    {:noreply,
    assign(socket,
      selected_tab: tab,
      feed: e(followers, :edges, []),
      page_info: e(followers, :page_info, [])
    )}
  end


  def do_handle_params(%{"tab" => "followed" =tab} = _params, _url, socket) do
    user = e(socket, :assigns, :user, nil)
    followed = Bonfire.Social.Follows.list_followed(user, socket) |> debug("followed")

    {:noreply,
    assign(socket,
      selected_tab: tab,
      feed: e(followed, :edges, []),
      page_info: e(followed, :page_info, [])
    )}
  end


  def do_handle_params(%{"tab" => tab} = _params, _url, socket) do
    # something that may be added by another extension?
    {:noreply,
     assign(socket,
       selected_tab: tab,
     )}
  end

  def do_handle_params(%{} = _params, _url, socket) do
    # default tab
    do_handle_params(%{"tab" => "timeline"}, nil, socket)
  end

  def handle_params(params, uri, socket) do
    undead_params(socket, fn ->
      do_handle_params(params, uri, socket)
    end)
  end

  def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  def handle_info(info, socket), do: Bonfire.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

end
