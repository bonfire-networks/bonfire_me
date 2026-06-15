defmodule Bonfire.Me.Users.ReindexTest do
  use Bonfire.Me.DataCase, async: false
  use Repatch.ExUnit

  alias Bonfire.Me.Users.Reindex
  import Bonfire.Me.Fake

  test "groups a batch by index and calls Indexer.maybe_index_object once per group" do
    pub1 = fake_user!()
    pub2 = fake_user!()

    closed =
      current_user(
        Bonfire.Common.Settings.put([Bonfire.Me.Users, :undiscoverable], true,
          current_user: fake_user!()
        )
      )

    test_pid = self()

    Repatch.patch(Bonfire.Search.Indexer, :maybe_index_object, fn group, index ->
      send(test_pid, {:indexed, index, group |> Enum.map(& &1.id) |> Enum.sort()})
      {:ok, :indexed}
    end)

    Reindex.migrate([pub1, pub2, closed])

    assert_receive {:indexed, :public, public_ids}
    assert_receive {:indexed, :closed, closed_ids}

    assert public_ids == Enum.sort([pub1.id, pub2.id])
    assert closed_ids == [closed.id]
  end

  # Live end-to-end: only runs when Sonic is the configured search adapter.
  # Asserts via Bonfire.Search (Sonic) directly — NOT Bonfire.Me.Users.search/1, which
  # falls back to a DB query and would pass even if indexing never happened.
  if Application.compile_env(:bonfire_search, :adapter) == Bonfire.Search.Sonic do
    setup do
      # enable the Indexer module in test (otherwise `module_enabled?(Indexer)` is false and
      # `Indexer.maybe_index_object` won't actually push). Global put is fine — this test is async: false.
      Bonfire.Common.Config.put([Bonfire.Search.Indexer, :modularity], true, :bonfire_search)

      on_exit(fn ->
        Bonfire.Common.Config.put([Bonfire.Search.Indexer, :modularity], false, :bonfire_search)
      end)

      :ok
    end

    test "live: reindex_local indexes local users into Sonic so they're searchable" do
      user = Bonfire.Common.Repo.maybe_preload(fake_user!(), [:character, :profile])
      username = user.character.username

      sonic_search = fn ->
        Bonfire.Search.search_by_type(username, Bonfire.Data.Identity.User,
          skip_boundary_check: true
        ) || []
      end

      ids = fn results -> Enum.map(results, &(e(&1, "id", nil) || e(&1, :id, nil))) end

      # Clear any creation-time indexing so the hit below can ONLY be explained by
      # reindex_local — otherwise fake_user! already indexes on create and the test
      # would pass without exercising reindex at all.
      for index <- [:public, :closed] do
        Bonfire.Search.adapter().delete(:all, Bonfire.Search.Indexer.index_name(index))
      end

      refute user.id in ids.(sonic_search.()), "expected index cleared before reindex"

      assert :ok = Bonfire.Me.Users.Reindex.reindex()

      assert user.id in ids.(sonic_search.())
    end
  end
end
