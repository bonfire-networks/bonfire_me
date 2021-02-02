defmodule Bonfire.Me.Web.ThreadLive do
  use Bonfire.Web, {:live_view, [layout: {Bonfire.Web.LayoutView, "without_sidebar.html"}]}
  alias Bonfire.Fake
  alias Bonfire.Common.Web.LivePlugs
  alias Bonfire.Me.Users
  alias Bonfire.Me.Web.{CreateUserLive, LoggedDashboardLive}
  import Bonfire.Me.Integration

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
    thread = with {:ok, post} <- Bonfire.Me.Social.Posts.get(Map.get(params, "post_id")) do
      post |> repo().maybe_preload([thread_replies: [activity: [:verb, subject_user: [:profile, :character]], post: [:post_content]]])
      # TODO: handle error
    end
    # IO.inspect(thread)

    replies = Bonfire.Me.Social.Posts.replies_tree(e(thread, :thread_replies, []))
    IO.inspect(replies)

    {:ok,
     socket
     |> assign(
       page_title: "Thread",
       thread: thread,
       replies: replies || []
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

  def handle_event("reply", attrs, socket) do

    Bonfire.Me.Social.Posts.live_post(attrs, socket)
  end

end
