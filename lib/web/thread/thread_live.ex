defmodule Bonfire.Me.Web.ThreadLive do
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
    thread = with {:ok, post} <- Bonfire.Me.Social.Posts.get(Map.get(params, "post_id")) do
      post
      #|> repo().maybe_preload([:replied, thread_replies: [activity: [:verb, subject_user: [:profile, :character]], post: [:post_content, created: [:creator]]]])
    else _e ->
      # TODO: handle error
      nil
    end
    IO.inspect(thread, label: "THREAD:")

    # replies = Bonfire.Data.Social.Replied.descendants(thread)
    # IO.inspect(replies, label: "REPLIES:")
    # replies = replies |> repo().all

    # replies = Bonfire.Me.Social.Posts.replies_tree(e(thread, :thread_replies, []))

    replies = if thread, do: Bonfire.Me.Social.Posts.list_replies(thread, @thread_max_depth)
    # IO.inspect(replies, label: "REPLIES:")

    {:ok,
     socket
     |> assign(
       page_title: "Thread",
       thread_max_depth: @thread_max_depth,
       thread: thread,
       replies: replies || [],
       threaded_replies: Bonfire.Me.Social.Posts.arrange_replies_tree(replies || []) || []
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

  def handle_event("load_replies", %{"id" => id, "level" => level}, socket) do
    {level, _} = Integer.parse(level)
    replies = Bonfire.Me.Social.Posts.list_replies(id, level + @thread_max_depth)
    replies = replies ++ socket.assigns.replies
    {:noreply,
        assign(socket,
        replies: replies,
        threaded_replies: Bonfire.Me.Social.Posts.arrange_replies_tree(replies) || []
     )}
  end

  def handle_event("reply", attrs, socket) do

    attrs = attrs
    |> Bonfire.Common.Utils.input_to_atoms()

    with {:ok, published} <- Bonfire.Me.Social.Posts.reply(socket.assigns.current_user, attrs) do
      replies = [published] ++ socket.assigns.replies
    IO.inspect(replies, label: "rep:")
      {:noreply,
        assign(socket,
        replies: replies,
        threaded_replies: Bonfire.Me.Social.Posts.arrange_replies_tree(replies) || []
     )}
    end

  end

end
