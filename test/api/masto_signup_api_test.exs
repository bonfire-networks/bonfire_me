# SPDX-License-Identifier: AGPL-3.0-only
if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.Me.Web.MastoSignupApiTest do
    @moduledoc """
    Tests for Mastodon-compatible POST /api/v1/accounts endpoint.

    Tests Mastodon's email confirmation behavior per PR #17530:
    - Token is returned immediately after signup
    - API calls return 403 until email is confirmed
    - After confirmation, API works normally

    Run with: just test extensions/bonfire_me/test/api/masto_signup_api_test.exs
    """

    use Bonfire.Me.ConnCase, async: false

    alias Bonfire.OpenID.Provider.ClientApps
    alias Boruta.Ecto.AccessTokens, as: AccessTokensAdapter
    import Boruta.Ecto.OauthMapper, only: [to_oauth_schema: 1]

    @moduletag :masto_api

    setup do
      # Create OAuth client using ClientApps.new which handles all the setup
      client_id = Faker.UUID.v4()

      # Use a valid HTTP redirect URI (Boruta rejects URN URIs like urn:ietf:wg:oauth:2.0:oob)
      {:ok, ecto_client} =
        ClientApps.new(%{
          id: client_id,
          name: "test-signup-app",
          redirect_uris: ["http://localhost:4000/oauth/callback"]
        })

      # Convert Ecto client to OAuth client for token creation
      oauth_client = to_oauth_schema(ecto_client)

      # For app tokens (client credentials), sub should be nil (no user)
      {:ok, app_token} =
        AccessTokensAdapter.create(
          %{client: oauth_client, sub: nil, scope: "read write follow push write:accounts"},
          []
        )

      conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-type", "application/json")

      # No on_exit cleanup needed - test sandbox handles rollback
      {:ok, conn: conn, app_token: app_token}
    end

    defp with_app_token(conn, app_token) do
      put_req_header(conn, "authorization", "Bearer #{app_token.value}")
    end

    defp unique_signup_params(suffix \\ System.unique_integer([:positive])) do
      %{
        "username" => "testuser#{suffix}",
        "email" => "testuser#{suffix}@example.com",
        "password" => "password123!",
        "agreement" => true
      }
    end

    describe "POST /api/v1/accounts" do
      test "creates account and returns token", %{conn: conn, app_token: app_token} do
        params = unique_signup_params()

        response =
          conn
          |> with_app_token(app_token)
          |> post("/api/v1/accounts", params)
          |> json_response(200)

        assert response["token_type"] == "Bearer"
        assert Map.has_key?(response, "access_token")
        assert Map.has_key?(response, "scope")
        assert Map.has_key?(response, "created_at")
      end

      test "returns 403 on verify_credentials for unconfirmed account", %{
        conn: conn,
        app_token: app_token
      } do
        params = unique_signup_params()

        signup_response =
          conn
          |> with_app_token(app_token)
          |> post("/api/v1/accounts", params)
          |> json_response(200)

        # Token is returned but API access should be blocked
        verify_response =
          Phoenix.ConnTest.build_conn()
          |> put_req_header("accept", "application/json")
          |> put_req_header("authorization", "Bearer #{signup_response["access_token"]}")
          |> get("/api/v1/accounts/verify_credentials")
          |> json_response(403)

        assert verify_response["error"] =~ "confirmed"
      end

      test "verify_credentials works after email confirmation", %{
        conn: conn,
        app_token: app_token
      } do
        params = unique_signup_params()

        signup_response =
          conn
          |> with_app_token(app_token)
          |> post("/api/v1/accounts", params)
          |> json_response(200)

        # Confirm the email directly (simulating clicking the confirmation link)
        {:ok, _account} = Bonfire.Me.Accounts.confirm_email_manually(params["email"])

        # Now verify_credentials should work
        verify_response =
          Phoenix.ConnTest.build_conn()
          |> put_req_header("accept", "application/json")
          |> put_req_header("authorization", "Bearer #{signup_response["access_token"]}")
          |> get("/api/v1/accounts/verify_credentials")
          |> json_response(200)

        assert verify_response["username"] == params["username"]
      end

      test "returns 422 for missing required fields", %{conn: conn, app_token: app_token} do
        response =
          conn
          |> with_app_token(app_token)
          |> post("/api/v1/accounts", %{"username" => "testuser"})
          |> json_response(422)

        assert response["error"] =~ "required"
      end

      test "returns 422 when agreement is not accepted", %{conn: conn, app_token: app_token} do
        response =
          conn
          |> with_app_token(app_token)
          |> post("/api/v1/accounts", %{unique_signup_params() | "agreement" => false})
          |> json_response(422)

        assert response["error"] =~ "agreement"
      end

      test "returns 401 without app token", %{conn: conn} do
        response =
          conn
          |> post("/api/v1/accounts", unique_signup_params())
          |> json_response(401)

        assert response["error"] =~ "invalid"
      end

      test "returns 401 with invalid app token", %{conn: conn} do
        response =
          conn
          |> put_req_header("authorization", "Bearer invalid_token_here")
          |> post("/api/v1/accounts", unique_signup_params())
          |> json_response(401)

        assert response["error"] =~ "invalid"
      end

      test "returns 422 for duplicate username", %{conn: conn, app_token: app_token} do
        unique = System.unique_integer([:positive])

        conn
        |> with_app_token(app_token)
        |> post("/api/v1/accounts", unique_signup_params(unique))
        |> json_response(200)

        response =
          conn
          |> with_app_token(app_token)
          |> post("/api/v1/accounts", %{
            unique_signup_params(unique)
            | "email" => "other#{unique}@example.com"
          })
          |> json_response(422)

        assert Map.has_key?(response, "error")
      end

      test "returns 422 for duplicate email", %{conn: conn, app_token: app_token} do
        unique = System.unique_integer([:positive])

        conn
        |> with_app_token(app_token)
        |> post("/api/v1/accounts", unique_signup_params(unique))
        |> json_response(200)

        response =
          conn
          |> with_app_token(app_token)
          |> post("/api/v1/accounts", %{
            unique_signup_params(unique)
            | "username" => "other#{unique}"
          })
          |> json_response(422)

        assert Map.has_key?(response, "error")
      end
    end

    describe "POST /api/v1/emails/confirmations" do
      test "resend confirmation returns 200 for unconfirmed account", %{
        conn: conn,
        app_token: app_token
      } do
        params = unique_signup_params()

        signup_response =
          conn
          |> with_app_token(app_token)
          |> post("/api/v1/accounts", params)
          |> json_response(200)

        # Request resend confirmation
        Phoenix.ConnTest.build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{signup_response["access_token"]}")
        |> post("/api/v1/emails/confirmations", %{})
        |> json_response(200)
      end
    end

    describe "GET /api/v1/accounts/lookup" do
      test "lookup works for unconfirmed account", %{conn: conn, app_token: app_token} do
        params = unique_signup_params()

        signup_response =
          conn
          |> with_app_token(app_token)
          |> post("/api/v1/accounts", params)
          |> json_response(200)

        # Lookup should work even for unconfirmed accounts (Mastodon behavior)
        lookup_response =
          Phoenix.ConnTest.build_conn()
          |> put_req_header("accept", "application/json")
          |> put_req_header("authorization", "Bearer #{signup_response["access_token"]}")
          |> get("/api/v1/accounts/lookup", %{"acct" => params["username"]})
          |> json_response(200)

        assert lookup_response["username"] == params["username"]
      end
    end
  end
end
