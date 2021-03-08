defmodule Bonfire.Me.Web.PostLive do
  use Bonfire.Web, {:live_view, [layout: {Bonfire.Web.LayoutView, "thread.html"}]}
  alias Bonfire.Fake
  alias Bonfire.Common.Web.LivePlugs
  alias Bonfire.Me.Users
  alias Bonfire.Me.Web.{CreateUserLive, LoggedDashboardLive}
  import Bonfire.Me.Integration

  @thread_max_depth 3 # TODO: put in config

  def mount(params, session, socket) do
    LivePlugs.live_plug(params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      LivePlugs.LoadCurrentAccountUsers,
      LivePlugs.StaticChanged,
      LivePlugs.Csrf,
      &mounted/3
    ])
  end

  defp mounted(params, session, socket) do

    # TODO: optimise to reduce num of queries
    post = with {:ok, post} <- Bonfire.Me.Social.Posts.read(Map.get(params, "post_id"), e(socket, :assigns, :current_user, nil)) do
      post
      #|> repo().maybe_preload([:replied, thread_replies: [activity: [:verb, subject_user: [:profile, :character]], post: [:post_content, created: [:creator]]]])
      IO.inspect(post, label: "the post:")
    else _e ->
      # TODO: handle error
      nil
    end

    {:ok,
     socket
     |> assign(
       page_title: "Post",
       post: post
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

end
