defmodule Bonfire.Me.UserCirclesTest do

  use Bonfire.DataCase, async: true
  alias Bonfire.Data.AccessControl.Circle
  alias Bonfire.Me.Fake
  alias Bonfire.Me.Users
  alias Bonfire.Me.Users.Circles
  alias Bonfire.Repo

  # test "listing instance-wide circles (which I am permitted to see) works" do
  #   user = fake_user!()
  #   assert circles = Circles.list_visible(user)
  #   presets = Bonfire.Boundaries.Circles.circles() |> Map.keys()
  #   assert length(circles) == length(presets)
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
  #   assert [c] = Circles.list_my(user)
  #   # assert [c] = Enum.filter(circles, &real_circle?/1)
  #   c = Repo.preload(c, [:named, :caretaker])
  #   assert c.named.name == name
  #   assert c.caretaker.caretaker_id == user.id
  # end

  # defp real_circle?(%Circle{}), do: true
  # defp real_circle?(_), do: false

  # test "cannot list someone else's circles (which they're caretaker of) " do
  #   user = fake_user!()
  #   name = "test circle"
  #   assert {:ok, circle} = Circles.create(user, name)
  #   me = fake_user!()
  #   assert circles = Circles.list_my(me)
  #   assert length(circles) == 0
  # end

  # test "listing circles I am permitted to see works" do
  #   user = fake_user!()
  #   name = "test circle"
  #   assert {:ok, circle} = Circles.create(user, name)
  #   circles = Circles.list_visible(user)
  #   assert is_list(circles) and length(circles) > length(Bonfire.Boundaries.Circles.list_builtins())
  #   assert [_] =
  #     circles
  #     |> Repo.preload([:named, :caretaker])
  #     |> Enum.filter(&(name == &1.named.name && user.id == &1.caretaker.caretaker_id))
  # end

  # test "cannot list circles which I am not permitted to see" do
  #   me = fake_user!()
  #   user = fake_user!()
  #   IO.inspect(me: me)
  #   name = "test circle by other user"
  #   assert {:ok, circle} = Circles.create(user, name)
  #   circles =
  #     Circles.list_visible(me)
  #     |> Repo.preload([:named, :caretaker])
  #   IO.inspect(circles: circles)
  #   assert length(circles) == length(Bonfire.Boundaries.Circles.list_builtins())
  # end

end
