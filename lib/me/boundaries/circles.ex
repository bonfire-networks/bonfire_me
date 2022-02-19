defmodule Bonfire.Me.Boundaries.Circles do
  use Bonfire.Common.Utils

  alias Bonfire.Data.Identity.User
  alias Bonfire.Data.AccessControl.{Circle, Encircle}
  alias Bonfire.Boundaries.Circles
  alias Bonfire.Boundaries.Stereotype
  alias Bonfire.Me.Users

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
  def list_visible(user, opts \\ []), do: repo().many(list_visible_q(user, opts))

  @doc "query for `list_visible`"
  def list_visible_q(user, opts \\ []) do
    from(circle in Circle, as: :circle)
    |> boundarise(circle.id, opts ++ [current_user: user])
    |> proload([:named, :caretaker, stereotype: {"stereotype_",  [:named]}])
  end

  @doc """
  Lists the circles we are the registered caretakers of that we are
  permitted to see. If any circles are created without permitting the
  user to see them, they will not be shown.
  """
  def list_my(user, opts \\ []), do: repo().many(list_my_q(user, opts))

  @doc "query for `list_my`"
  def list_my_q(user, opts \\ []) do
    list_visible_q(user, opts)
    |> where([caretaker: caretaker], caretaker.caretaker_id == ^ulid(user))
  end

  def list_my_defaults(_user \\ nil) do
    # TODO make configurable
    Enum.map([:guest, :local, :activity_pub], &Circles.get_tuple/1)
  end

  def get(id, %User{}=user) do
    repo().single(get_q(id, user))
  end

  def get_stereotype_circle(subject, stereotype) when is_atom(stereotype) do
    get_stereotype_circle(subject, Bonfire.Boundaries.Circles.get_id!(stereotype))
  end
  def get_stereotype_circle(subject, stereotype) do
    list_my_q(subject, skip_boundary_check: true)
    |> where([circle: circle, stereotype: stereotype], stereotype.stereotype_id == ^ulid(stereotype))
    |> repo().single()
  end

  @doc "query for `get`"
  def get_q(id, user) do
    list_visible_q(user)
    |> join(:inner, [circle: circle], caretaker in assoc(circle, :caretaker), as: :caretaker)
    |> where([circle: circle, caretaker: caretaker], circle.id == ^id and caretaker.caretaker_id == ^ulid(user))
  end

  def update(id, %User{} = user, params) do
    with {:ok, circle} <- get(id, user)
    |> repo().maybe_preload([:encircles]) do

      repo().update(changeset(:update, circle, params))
    end
  end

  def add_to_circle(subject, circle) do
    repo().insert(Encircle.changeset(%{circle_id: ulid(circle), subject_id: ulid(subject)}))
  end

  def changeset(:create, %User{}=_user, attrs) do
    Circles.changeset(:create, attrs)
  end

  def changeset(:update, circle, params) do

    # Ecto doesn't like mixed keys so we convert them all to strings
    params = for {k, v} <- params, do: {to_string(k), v}, into: %{}
    # debug(params)

    circle
    |> Circles.changeset(params)
  end

end
