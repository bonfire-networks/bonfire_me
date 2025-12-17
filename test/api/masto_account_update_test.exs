# SPDX-License-Identifier: AGPL-3.0-only
if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.Me.Web.MastoAccountUpdateTest do
    @moduledoc """
    Tests for Mastodon-compatible PATCH /api/v1/accounts/update_credentials endpoint.

    Allows updating user profile information: display name, bio, avatar, and banner.

    Run with: just test extensions/bonfire_me/test/api/masto_account_update_test.exs
    """

    use Bonfire.Me.ConnCase, async: false

    alias Bonfire.Me.Fake
    alias Bonfire.Me.Users

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

      {:ok, conn: conn, user: user, account: account}
    end

    defp unauthenticated_conn do
      Phoenix.ConnTest.build_conn()
      |> put_req_header("accept", "application/json")
    end

    describe "PATCH /api/v1/accounts/update_credentials" do
      test "updates display_name", %{conn: conn, user: user} do
        response =
          conn
          |> patch("/api/v1/accounts/update_credentials", %{
            "display_name" => "New Display Name"
          })
          |> json_response(200)

        assert response["display_name"] == "New Display Name"

        # Verify database state
        {:ok, updated_user} = Users.by_id(user.id)
        assert updated_user.profile.name == "New Display Name"
      end

      test "updates note/bio", %{conn: conn, user: user} do
        response =
          conn
          |> patch("/api/v1/accounts/update_credentials", %{
            "note" => "My new bio"
          })
          |> json_response(200)

        # Note is stored as plaintext in source
        assert response["source"]["note"] == "My new bio"

        # Verify database state
        {:ok, updated_user} = Users.by_id(user.id)
        assert updated_user.profile.summary == "My new bio"
      end

      test "updates multiple fields at once", %{conn: conn, user: user} do
        response =
          conn
          |> patch("/api/v1/accounts/update_credentials", %{
            "display_name" => "Updated Name",
            "note" => "Updated bio"
          })
          |> json_response(200)

        assert response["display_name"] == "Updated Name"
        assert response["source"]["note"] == "Updated bio"

        # Verify database state
        {:ok, updated_user} = Users.by_id(user.id)
        assert updated_user.profile.name == "Updated Name"
        assert updated_user.profile.summary == "Updated bio"
      end

      test "returns full account object with all expected fields", %{conn: conn} do
        response =
          conn
          |> patch("/api/v1/accounts/update_credentials", %{
            "display_name" => "Test User"
          })
          |> json_response(200)

        # Verify Mastodon Account schema fields are present
        assert Map.has_key?(response, "id")
        assert Map.has_key?(response, "username")
        assert Map.has_key?(response, "acct")
        assert Map.has_key?(response, "display_name")
        assert Map.has_key?(response, "note")
        assert Map.has_key?(response, "url")
        assert Map.has_key?(response, "avatar")
        assert Map.has_key?(response, "avatar_static")
        assert Map.has_key?(response, "header")
        assert Map.has_key?(response, "header_static")
        assert Map.has_key?(response, "created_at")
        assert Map.has_key?(response, "source")

        # Verify source has expected fields for CredentialAccount
        source = response["source"]
        assert Map.has_key?(source, "note")
        assert Map.has_key?(source, "privacy")
        assert Map.has_key?(source, "sensitive")
      end

      test "empty update returns current profile", %{conn: conn, user: user} do
        response =
          conn
          |> patch("/api/v1/accounts/update_credentials", %{})
          |> json_response(200)

        assert response["id"] == user.id
        assert Map.has_key?(response, "username")
      end

      test "ignores nil values", %{conn: conn, user: user} do
        # First set a display name
        conn
        |> patch("/api/v1/accounts/update_credentials", %{
          "display_name" => "Original Name"
        })
        |> json_response(200)

        # Then send an update with nil display_name
        response =
          conn
          |> patch("/api/v1/accounts/update_credentials", %{
            "display_name" => nil,
            "note" => "Updated bio"
          })
          |> json_response(200)

        # Bio should be updated, display_name should remain unchanged
        assert response["source"]["note"] == "Updated bio"
        assert response["display_name"] == "Original Name"
      end

      test "requires authentication" do
        response =
          unauthenticated_conn()
          |> patch("/api/v1/accounts/update_credentials", %{
            "display_name" => "Test"
          })
          |> json_response(401)

        assert response["error"] == "Unauthorized"
      end
    end
  end
end
