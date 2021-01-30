defmodule Bonfire.Me.Web.ProfileLive do
  use Bonfire.Web, :live_view
  alias Bonfire.Me.Web.HeroProfileLive
  alias Bonfire.Me.Web.ProfileNavigationLive
  alias Bonfire.Me.Web.ProfileAboutLive
  alias Bonfire.Me.Fake
  alias Bonfire.Common.Web.LivePlugs

  def mount(params, session, socket) do
    LivePlugs.live_plug params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      LivePlugs.StaticChanged,
      LivePlugs.Csrf,
      &mounted/3,
    ]
  end

  defp mounted(params, session, socket) do

    current_user = Map.get(socket.assigns, :current_user)

    user = case Map.get(params, "username") do
      nil -> e(socket.assigns, :current_user, Fake.user_live())
      username ->
        with {:ok, user} <- Bonfire.Me.Identity.Users.by_username(username) do
          user
        end
    end
    # IO.inspect(user)

    following = if current_user && user, do: Bonfire.Me.Social.Follows.following?(current_user, user)

    feed = if user, do: Bonfire.Me.Social.Activities.by_user(user)

    {:ok,
      socket
      |> assign(
        page_title: "Profile",
        selected_tab: "about",
        feed_title: "User feed",
        current_account: Map.get(socket.assigns, :current_account),
        current_user: current_user,
        user: user, # the user to display
        following: following,
        feed: feed || []
      )}
  end

  # def handle_params(%{"tab" => tab} = _params, _url, socket) do
  #   {:noreply,
  #    assign(socket,
  #      selected_tab: tab
  #    )}
  # end

  # def handle_params(%{} = _params, _url, socket) do
  #   {:noreply,
  #    assign(socket,
  #      current_user: Fake.user_live()
  #    )}
  # end

  def handle_event("follow", _, socket) do
    with {:ok, _follow} <- Bonfire.Me.Social.Follows.follow(e(socket.assigns, :current_user, nil), e(socket.assigns, :user, nil)) do
      {:noreply, assign(socket,
       following: true
     )}
    else e ->
      {:noreply, socket} # TODO: handle errors
    end
  end

  def handle_event("unfollow", _, socket) do
    with _ <- Bonfire.Me.Social.Follows.unfollow(e(socket.assigns, :current_user, nil), e(socket.assigns, :user, nil)) do
      {:noreply, assign(socket,
       following: false
     )}
    else e ->
      {:noreply, socket} # TODO: handle errors
    end
  end
end
