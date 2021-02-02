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

  def live_post(%{"note"=> note}, socket) do
    with {:ok, published} <- publish(socket.assigns.current_user, %{html_body: note}) do
      {:ok,
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
  end

  def get(id) do
    repo().single(get_query(id))
  end

  def get_query(id) do
    from p in Post,
     join: pc in assoc(p, :post_content),
     join: cr in assoc(p, :created),
     where: p.id == ^id,
     preload: [post_content: pc, created: cr]
  end

  def by_user(user_id) do
    repo().all(by_user_query(user_id))
  end

  def by_user_query(user_id) do
    from p in Post,
     join: pc in assoc(p, :post_content),
     join: cr in assoc(p, :created),
     where: cr.creator_id == ^user_id,
     preload: [post_content: pc, created: cr]
  end
end
