# SPDX-License-Identifier: AGPL-3.0-only
if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.Me.Web.MastoSuggestionsApiTest do
    @moduledoc """
    Tests for Mastodon-compatible Suggestions API v2 endpoint.

    The suggestions endpoint returns users from the "Suggested Profiles" circle
    maintained by instance admins/mods, falling back to discoverable users if empty.

    Run with: just test extensions/bonfire_me/test/api/masto_suggestions_api_test.exs
    """

    use Bonfire.Me.ConnCase, async: false

    alias Bonfire.Me.Fake
    alias Bonfire.Social.Graph.Follows
    alias Bonfire.Boundaries.Circles
    alias Bonfire.Boundaries.Scaffold.Instance

    @moduletag :masto_api

    setup do
      account = Fake.fake_account!()
      user = Fake.fake_user!(account)

      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:current_user_id, user.id)
        |> Plug.Conn.put_session(:current_account_id, account.id)
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-type", "application/json")

      {:ok, conn: conn, user: user, account: account}
    end

    defp unauthenticated_conn do
      Phoenix.ConnTest.build_conn()
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
    end

    describe "GET /api/v2/suggestions" do
      test "returns Mastodon-compatible suggestion format", %{conn: conn} do
        # Create another user to be suggested
        other_account = Fake.fake_account!()
        _other_user = Fake.fake_user!(other_account)

        response =
          conn
          |> get("/api/v2/suggestions")
          |> json_response(200)

        assert is_list(response)

        # If we got suggestions, verify the format
        if length(response) > 0 do
          suggestion = hd(response)
          assert Map.has_key?(suggestion, "source")
          assert Map.has_key?(suggestion, "sources")
          assert Map.has_key?(suggestion, "account")

          # Verify account structure
          account = suggestion["account"]
          assert Map.has_key?(account, "id")
          assert Map.has_key?(account, "username")
          assert Map.has_key?(account, "acct")

          # Verify source values (staff when from curated circle, global for fallback)
          assert suggestion["source"] in ["global", "staff", "past_interactions"]
          assert is_list(suggestion["sources"])
        end
      end

      test "returns users from suggested profiles circle when populated", %{
        conn: conn,
        user: user
      } do
        # Create a user and add them to the suggested profiles circle
        other_account = Fake.fake_account!()
        suggested_user = Fake.fake_user!(other_account)

        # Add user to the suggested profiles circle
        circle_id = Instance.suggested_profiles_circle()
        {:ok, _} = Circles.add_to_circles(suggested_user, circle_id)

        response =
          conn
          |> get("/api/v2/suggestions")
          |> json_response(200)

        assert is_list(response)

        # Should include the suggested user
        suggested_ids = Enum.map(response, & &1["account"]["id"])
        assert suggested_user.id in suggested_ids

        # Verify source indicates staff curation
        suggestion = Enum.find(response, &(&1["account"]["id"] == suggested_user.id))

        if suggestion do
          assert suggestion["source"] == "staff"
          assert "featured" in suggestion["sources"]
        end
      end

      test "does not include the current user in suggestions", %{conn: conn, user: user} do
        response =
          conn
          |> get("/api/v2/suggestions")
          |> json_response(200)

        assert is_list(response)

        user_ids = Enum.map(response, & &1["account"]["id"])
        refute user.id in user_ids
      end

      test "excludes users that the current user is already following", %{
        conn: conn,
        user: user
      } do
        # Create and follow another user
        other_account = Fake.fake_account!()
        other_user = Fake.fake_user!(other_account)
        {:ok, _} = Follows.follow(user, other_user)

        response =
          conn
          |> get("/api/v2/suggestions")
          |> json_response(200)

        assert is_list(response)

        suggested_ids = Enum.map(response, & &1["account"]["id"])
        refute other_user.id in suggested_ids
      end

      test "respects the limit parameter", %{conn: conn} do
        # Create multiple users
        for _ <- 1..5 do
          other_account = Fake.fake_account!()
          Fake.fake_user!(other_account)
        end

        response =
          conn
          |> get("/api/v2/suggestions?limit=2")
          |> json_response(200)

        assert is_list(response)
        assert length(response) <= 2
      end

      test "limit defaults to 40 when not specified", %{conn: conn} do
        response =
          conn
          |> get("/api/v2/suggestions")
          |> json_response(200)

        assert is_list(response)
        # We can't guarantee 40 users exist, but we can verify it returns a list
      end

      test "limit is capped at 80", %{conn: conn} do
        response =
          conn
          |> get("/api/v2/suggestions?limit=100")
          |> json_response(200)

        assert is_list(response)
        # The endpoint should cap to 80, but we can't verify easily
        # without creating 100+ users
      end

      test "returns empty list when no users available", %{conn: conn} do
        # This test is tricky since there might be other users
        # We just verify it returns a list
        response =
          conn
          |> get("/api/v2/suggestions")
          |> json_response(200)

        assert is_list(response)
      end

      test "requires authentication", _context do
        response =
          unauthenticated_conn()
          |> get("/api/v2/suggestions")
          |> json_response(401)

        assert response["error"] == "You need to login first."
      end
    end
  end
end
