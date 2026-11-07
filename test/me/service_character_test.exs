defmodule Bonfire.Me.ServiceCharacterTest do
  @moduledoc "The instance's federation bot is not a person. It has no account, so it never takes the first account or first user slot that a real first signup needs, and it is never made an admin. It is made at install, before anyone signs up."
  use Bonfire.Me.DataCase, async: false
  use Repatch.ExUnit

  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Fake
  alias Bonfire.Me.Users

  # the federation adapter fixes the id and username of the real bot; any valid ones will do here
  defp make_bot!(id \\ Needle.UID.generate(), username \\ nil) do
    Users.get_or_create_service_character(
      id,
      username || "bot#{System.unique_integer([:positive])}",
      "A bot made in a test",
      "Test bot"
    )
  end

  test "making the bot adds no account" do
    before = Accounts.count()
    make_bot!()

    assert Accounts.count() == before
  end

  test "making the bot adds no one to the users who have an account" do
    before = Users.count(:with_account)
    make_bot!()

    assert Users.count(:with_account) == before
  end

  test "the bot has no account" do
    bot = make_bot!() |> repo().preload(:accounted)

    assert is_nil(bot.accounted)
  end

  test "making the bot does not change who counts as the first account or the first user" do
    Fake.clear_caches()
    first_account? = Accounts.is_first_account?()
    first_user? = Users.is_first_user?()

    make_bot!()

    Fake.clear_caches()
    assert Accounts.is_first_account?() == first_account?
    assert Users.is_first_user?() == first_user?
  end

  test "the bot is never made an admin, even when it would be the first account and the first user" do
    # first account and first user are made admin, but not in the test env, and the counts depend on what else is in the database, so set both
    Process.put([:bonfire, :env], :prod)
    Repatch.patch(Accounts, :is_first_account?, fn -> true end)
    Repatch.patch(Users, :is_first_user?, fn -> true end)

    bot = make_bot!()

    refute Enum.any?(Users.list_admins(), &(&1.id == bot.id))
  end

  test "making or revoking admin on the bot is refused with an error, not a crash" do
    bot = make_bot!()

    assert {:error, _} = Users.make_admin(bot)
    assert {:error, _} = Users.revoke_admin(bot)
  end

  test "making the bot again returns the same bot and adds nothing" do
    id = Needle.UID.generate()
    first = make_bot!(id, "bot_made_twice")
    accounts = Accounts.count()
    users = Users.count()

    again = make_bot!(id, "bot_made_twice")

    assert again.id == first.id
    assert Accounts.count() == accounts
    assert Users.count() == users
  end

  test "the bot can be deleted" do
    bot = make_bot!()

    assert {:ok, _} = Bonfire.Me.DeleteWorker.delete_structs_now(bot)
  end
end
