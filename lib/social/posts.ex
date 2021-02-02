defmodule Bonfire.Me.Social.Posts do

  alias Bonfire.Data.Social.{Post, PostContent}
  alias Ecto.Changeset
  import Ecto.Query

  import Bonfire.Me.Integration

  def draft(creator, attrs) do
    # TODO: create as private
    with {:ok, post} <- create(creator, attrs) do
      {:ok, post}
    end
  end

  def publish(creator, attrs) do
    with {:ok, post} <- create(creator, attrs) do
      activity = Bonfire.Me.Social.Feeds.publish(creator, :create, post)
      {:ok, %{post: post, activity: activity}}
    end
  end

  def live_post(params, socket) do
    attrs = params
    |> Bonfire.Common.Utils.input_to_atoms()
    # |> IO.inspect

    with {:ok, published} <- publish(socket.assigns.current_user, attrs) do
      {:noreply,
        Phoenix.LiveView.assign(socket,
          feed: [published.activity] ++ Map.get(socket.assigns, :feed, [])
      )}
    end
  end

  defp create(creator, attrs) do
    attrs = attrs
      |> Map.put(:created, %{creator_id: creator.id})
      |> Map.put(:post_content, Map.merge(attrs, Map.get(attrs, :post_content, %{})))

    repo().put(changeset(:create, attrs))
  end

  defp changeset(:create, attrs) do
    Post.changeset(%Post{}, attrs)
    |> Changeset.cast_assoc(:post_content, [:required, with: &PostContent.changeset/2])
    |> Changeset.cast_assoc(:created)
    |> Changeset.cast_assoc(:reply_to)
  end

  def get(id) do
    repo().single(get_query(id))
  end

  def get_query(id) do
    from p in Post,
     left_join: pc in assoc(p, :post_content),
     left_join: cr in assoc(p, :created),
     left_join: rt in assoc(p, :reply_to),
     where: p.id == ^id,
     preload: [post_content: pc, created: cr, reply_to: rt]
  end

  def by_user(user_id) do
    repo().all(by_user_query(user_id))
  end

  def by_user_query(user_id) do
    from p in Post,
     left_join: pc in assoc(p, :post_content),
     left_join: cr in assoc(p, :created),
     where: cr.creator_id == ^user_id,
     preload: [post_content: pc, created: cr]
  end



  def replies_tree(replies) do
    thread = replies
    |> Enum.reverse()
    |> Enum.map(&Map.from_struct/1)
    |> Enum.reduce(%{}, &Map.put(&2, &1.id, &1))
    # |> IO.inspect

    do_reply_tree = fn
      {_id, %{reply_to_id: reply_to_id, thread_id: thread_id} =_reply} = reply_with_id,
      acc
      when is_binary(reply_to_id) and reply_to_id != thread_id ->
        # IO.inspect(acc: acc)
        # IO.inspect(reply_ok: reply)
        # IO.inspect(reply_to_id: reply_to_id)

        if Map.get(acc, reply_to_id) do

            acc
            |> put_in(
                [reply_to_id, :direct_replies],
                Bonfire.Common.Utils.maybe_get(acc[reply_to_id], :direct_replies, []) ++ [reply_with_id]
              )
            # |> IO.inspect
            # |> Map.delete(id)

        else
          acc
        end

      reply, acc ->
        # IO.inspect(reply_skip: reply)

        acc
    end

    Enum.reduce(thread, thread, do_reply_tree)
    |> Enum.reduce(thread, do_reply_tree)
    # |> IO.inspect
    |> Enum.reduce(%{}, fn

      {id, %{reply_to_id: reply_to_id, thread_id: thread_id} =reply} = reply_with_id, acc when not is_binary(reply_to_id) or reply_to_id == thread_id ->

        acc |> Map.put(id, reply)

      reply, acc ->

        acc

    end)
  end


end
