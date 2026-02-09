# SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.API.MastoApi.FollowRequestTest do
  @moduledoc """
  Tests for Mastodon-compatible Follow Requests API endpoints.

  Run with: just test extensions/bonfire_me/test/api/masto_follow_request_test.exs
  """

  # async: false required because Follows.accept_from/reject use transact_with
  # which conflicts with Ecto sandbox transactions in async mode
  use Bonfire.API.MastoApiCase, async: false

  alias Bonfire.Me.Fake
  alias Bonfire.Social.Graph.Follows

  @moduletag :masto_api

  describe "GET /api/v1/follow_requests" do
    test "lists incoming follow requests", %{conn: conn} do
      # User who will receive follow requests (requires approval)
      account = Fake.fake_account!()
      user = Fake.fake_user!(account, %{}, request_before_follow: true)

      # Create requesters
      requester1 = Fake.fake_user!()
      requester2 = Fake.fake_user!()

      # Send follow requests
      {:ok, _} = Follows.follow(requester1, user)
      {:ok, _} = Follows.follow(requester2, user)

      # Verify requests exist
      assert Follows.requested?(requester1, user)
      assert Follows.requested?(requester2, user)

      api_conn = masto_api_conn(conn, user: user, account: account)

      response =
        api_conn
        |> get("/api/v1/follow_requests")
        |> json_response(200)

      assert is_list(response)
      assert length(response) == 2

      # Each account should have required Mastodon Account fields
      Enum.each(response, fn acct ->
        assert is_binary(acct["id"])
        assert is_binary(acct["username"])
        assert is_binary(acct["acct"])
      end)

      # Verify requester IDs are in the response
      response_ids = Enum.map(response, & &1["id"])
      assert requester1.id in response_ids
      assert requester2.id in response_ids
    end

    test "returns empty list when no pending requests", %{conn: conn} do
      account = Fake.fake_account!()
      user = Fake.fake_user!(account)

      api_conn = masto_api_conn(conn, user: user, account: account)

      response =
        api_conn
        |> get("/api/v1/follow_requests")
        |> json_response(200)

      assert response == []
    end

    test "returns 401 when not authenticated", %{conn: conn} do
      response =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/api/v1/follow_requests")
        |> json_response(401)

      assert response["error"] == "Unauthorized"
    end
  end

  describe "GET /api/v1/follow_requests/outgoing" do
    test "lists outgoing follow requests", %{conn: conn} do
      # User who sends follow requests
      account = Fake.fake_account!()
      user = Fake.fake_user!(account)

      # Targets who require approval
      target1 = Fake.fake_user!(%{}, %{}, request_before_follow: true)
      target2 = Fake.fake_user!(%{}, %{}, request_before_follow: true)

      # Send follow requests
      {:ok, _} = Follows.follow(user, target1)
      {:ok, _} = Follows.follow(user, target2)

      api_conn = masto_api_conn(conn, user: user, account: account)

      response =
        api_conn
        |> get("/api/v1/follow_requests/outgoing")
        |> json_response(200)

      assert is_list(response)
      assert length(response) == 2

      response_ids = Enum.map(response, & &1["id"])
      assert target1.id in response_ids
      assert target2.id in response_ids
    end

    test "returns 401 when not authenticated", %{conn: conn} do
      response =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/api/v1/follow_requests/outgoing")
        |> json_response(401)

      assert response["error"] == "Unauthorized"
    end
  end

  describe "POST /api/v1/follow_requests/:account_id/authorize" do
    test "accepts a follow request and returns Relationship", %{conn: conn} do
      # User who will accept
      account = Fake.fake_account!()
      user = Fake.fake_user!(account, %{}, request_before_follow: true)

      # Requester
      requester = Fake.fake_user!()

      # Send follow request
      {:ok, _} = Follows.follow(requester, user)
      assert Follows.requested?(requester, user)
      refute Follows.following?(requester, user)

      api_conn = masto_api_conn(conn, user: user, account: account)

      response =
        api_conn
        |> post("/api/v1/follow_requests/#{requester.id}/authorize")
        |> json_response(200)

      # Should return Relationship object
      assert response["id"] == requester.id
      assert response["followed_by"] == true
      assert is_boolean(response["following"])
      assert is_boolean(response["blocking"])
      assert is_boolean(response["muting"])

      # Verify follow is now established
      assert Follows.following?(requester, user)
      refute Follows.requested?(requester, user)
    end

    test "returns 404 when no pending request exists", %{conn: conn} do
      account = Fake.fake_account!()
      user = Fake.fake_user!(account)
      other_user = Fake.fake_user!()

      api_conn = masto_api_conn(conn, user: user, account: account)

      response =
        api_conn
        |> post("/api/v1/follow_requests/#{other_user.id}/authorize")
        |> json_response(404)

      assert response["error"]
    end

    test "returns 401 when not authenticated", %{conn: conn} do
      user = Fake.fake_user!()

      response =
        conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/follow_requests/#{user.id}/authorize")
        |> json_response(401)

      assert response["error"] == "Unauthorized"
    end
  end

  describe "POST /api/v1/follow_requests/:account_id/reject" do
    test "rejects a follow request and returns Relationship", %{conn: conn} do
      # User who will reject
      account = Fake.fake_account!()
      user = Fake.fake_user!(account, %{}, request_before_follow: true)

      # Requester
      requester = Fake.fake_user!()

      # Send follow request
      {:ok, _} = Follows.follow(requester, user)
      assert Follows.requested?(requester, user)

      api_conn = masto_api_conn(conn, user: user, account: account)

      response =
        api_conn
        |> post("/api/v1/follow_requests/#{requester.id}/reject")
        |> json_response(200)

      # Should return Relationship object
      assert response["id"] == requester.id
      assert response["followed_by"] == false
      assert is_boolean(response["following"])

      # Verify request is removed and no follow exists
      refute Follows.following?(requester, user)
      refute Follows.requested?(requester, user)
    end

    test "returns 404 when no pending request exists", %{conn: conn} do
      account = Fake.fake_account!()
      user = Fake.fake_user!(account)
      other_user = Fake.fake_user!()

      api_conn = masto_api_conn(conn, user: user, account: account)

      response =
        api_conn
        |> post("/api/v1/follow_requests/#{other_user.id}/reject")
        |> json_response(404)

      assert response["error"]
    end

    test "returns 401 when not authenticated", %{conn: conn} do
      user = Fake.fake_user!()

      response =
        conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/follow_requests/#{user.id}/reject")
        |> json_response(401)

      assert response["error"] == "Unauthorized"
    end
  end
end
