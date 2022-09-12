defmodule Bonfire.Me.UserCirclesTest do
  use Bonfire.Me.DataCase, async: true
  alias Bonfire.Data.AccessControl.Circle
  alias Bonfire.Me.Fake
  alias Bonfire.Me.Users
  alias Bonfire.Boundaries.Circles
  alias Bonfire.Common.Repo

  # test "listing instance-wide circles (which I am permitted to see) works" do
  #   user = fake_user!()

  #   assert circles = Circles.list_visible(user)
  #   #preset_circles = Bonfire.Boundaries.Circles.circles() |> Map.keys()
  #   assert length(circles) == 0 #length(preset_circles)
  # end

  # test "creation works" do
  #   user = fake_user!()
  #   name = "test circle"
  #   assert {:ok, circle} = Circles.create(user, name)
  #   assert name == circle.named.name
  #   assert user.id == circle.caretaker.caretaker_id

  # end

  # test "listing my circles (which I'm caretaker of) works" do
  #   user = fake_user!()
  #   name = "test circle"
  #   assert {:ok, circle} = Circles.create(user, name)

  #   assert circles = Circles.list_my(user)
  #   assert is_list(circles) and length(circles) > length(Bonfire.Boundaries.Circles.list_builtins())

  #   my_circle = List.first(circles)
  #   my_circle = Repo.maybe_preload(my_circle, [:named, :caretaker])

  #   assert name == my_circle.named.name
  #   assert user.id == my_circle.caretaker.caretaker_id

  # end

  # test "cannot list someone else's circles (which they're caretaker of) " do

  #   user = fake_user!()
  #   name = "test circle"
  #   assert {:ok, circle} = Circles.create(user, name)

  #   me = fake_user!()
  #   assert circles = Circles.list_my(me)
  #   # debug(circles)
  #   assert length(circles) == length(Bonfire.Boundaries.Circles.list_builtins())

  # end

  # test "listing circles I am permitted to see works" do
  #   user = fake_user!()
  #   name = "test circle"
  #   assert {:ok, circle} = Circles.create(user, name)

  #   assert circles = Circles.list_visible(user)
  #   assert is_list(circles) and length(circles) > 0

  #   my_circle = List.first(circles)
  #   my_circle = Repo.maybe_preload(my_circle, [:named, :caretaker])

  #   assert name == my_circle.named.name
  #   assert user.id == my_circle.caretaker.caretaker_id

  # end

  # test "cannot list circles which I am not permitted to see" do
  #   me = fake_user!()
  #   user = fake_user!()
  #   name = "test circle by other user"
  #   assert {:ok, circle} = Circles.create(user, name)

  #   assert circles = Circles.list_visible(me)
  #   |> Repo.preload([:named, :caretaker])

  #   #debug(circles)
  #   assert length(circles) == 0
  # end
end
