defmodule Bonfire.Me.Users.Circles do

  alias Bonfire.Data.Identity.User
  alias Bonfire.Data.AccessControl.Circle
  alias Bonfire.Boundaries.Circles
  alias Bonfire.Me.Users
  alias Bonfire.Common.Utils

  import Bonfire.Me.Integration
  import Bonfire.Boundaries.Queries
  import Ecto.Query
  import EctoSparkles

  ## invariants:
  ## * Created circles will have the user as a caretaker


  @doc "Create a circle for the provided user (and with the user in the circle?)"
  def create(%User{}=user, name \\ nil, %{}=attrs \\ %{}) do
    with {:ok, circle} <- repo().insert(changeset(:create,
    user,
    attrs
      |> Utils.deep_merge(%{
        named: %{name: name},
        caretaker: %{caretaker_id: user.id}
        # encircles: [%{subject_id: user.id}] # add myself to circle?
      })
    )) do
      Users.Boundaries.maybe_make_visible_for(user, circle) # make visible to myself
      {:ok, circle}
    end
  end


  @doc """
  Lists the circles that we are permitted to see.
  """
  def list_visible(%User{}=user) do
    repo().many(list_visible_q(user))
  end

  @doc "query for `list_visible`"
  def list_visible_q(%User{id: _}=user) do
    from(circle in Circle, as: :circle)
    |> boundarise(circle.id, [current_user: user])
    |> proload(:named)
  end

  @doc """
  Lists the circles we are the registered caretakers of that we are
  permitted to see. If any circles are created without permitting the
  user to see them, they will not be shown.
  """
  def list_my(%User{}=user), do: repo().many(list_my_q(user))

  @doc "query for `list_my`"
  def list_my_q(%User{id: user_id}=user) do
    list_visible_q(user)
    |> join(:inner, [circle: circle], caretaker in assoc(circle, :caretaker), as: :caretaker)
    |> where([caretaker: caretaker], caretaker.caretaker_id == ^user_id)
  end

  def list_my_defaults(_user \\ nil) do
    # TODO make configurable
    Enum.map([:guest, :local, :activity_pub], &Circles.get_tuple/1)
  end

  def get(id, %User{}=user) do
    repo().single(get_q(id, user))
  end

  @doc "query for `get`"
  def get_q(id, %User{id: user_id}=user) do
    list_visible_q(user)
    |> join(:inner, [circle: circle], caretaker in assoc(circle, :caretaker), as: :caretaker)
    |> where([circle: circle, caretaker: caretaker], circle.id == ^id and caretaker.caretaker_id == ^user_id)
  end

  def update(id, %User{} = user, params) do
    with {:ok, circle} <- get(id, user)
    |> repo().maybe_preload([:encircles]) do

      repo().update(changeset(:update, circle, params))
    end
  end


  def changeset(:create, %User{}=_user, attrs) do
    Circles.changeset(:create, attrs)
  end

  def changeset(:update, circle, params) do

    # Ecto doesn't liked mixed keys so we convert them all to strings
    params = for {k, v} <- params, do: {to_string(k), v}, into: %{}
    IO.inspect(params)

    circle
    |> Circles.changeset(params)
  end

end
