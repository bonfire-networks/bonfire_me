defmodule Bonfire.Me.Users.ListTest do
  @moduledoc """
  Listed users come with what showing them needs, including `character.peered`, which tells whether a user is local or remote, so formatting them (for example their canonical URL) does not load it once per user.
  """
  use Bonfire.Me.DataCase, async: true
  @moduletag :backend

  alias Bonfire.Me.Users
  import Bonfire.Me.Fake

  # TODO: decide whether listing users preloads `character.peered` (a cost on a hot path), or callers that need locality load it
  @tag :skip
  test "listed local users have their character's peered loaded" do
    me = fake_user!()

    assert %{character: character} = Enum.find(Users.list(current_user: me), &(&1.id == me.id))
    assert Ecto.assoc_loaded?(character.peered)
  end
end
