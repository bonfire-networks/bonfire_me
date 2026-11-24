# SPDX-License-Identifier: AGPL-3.0-only
if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.Me.Web.MastoAccountsBulkApiTest do
    @moduledoc """
    `GET /api/v1/accounts?id[]=…`: Mastodon iOS reads reply-to authors with it and showed an HTTP 404 (masto-ios-baseline-fixes B42).

    Run with: just test extensions/bonfire_me/test/api/masto_accounts_bulk_api_test.exs
    """

    use Bonfire.Me.ConnCase, async: true

    alias Bonfire.Me.Fake

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

      {:ok, conn: conn, user: user}
    end

    test "GET /api/v1/accounts?id[]= returns the accounts asked for", %{conn: conn} do
      a = Fake.fake_user!(Fake.fake_account!())
      b = Fake.fake_user!(Fake.fake_account!())

      response = conn |> get("/api/v1/accounts", %{"id" => [a.id, b.id]}) |> json_response(200)

      assert Enum.map(response, & &1["id"]) == [a.id, b.id]

      for account <- response do
        assert is_binary(account["username"])
        assert is_binary(account["acct"])
        assert is_integer(account["followers_count"])
      end
    end

    test "leaves out an id that does not exist", %{conn: conn} do
      a = Fake.fake_user!(Fake.fake_account!())

      response =
        conn
        |> get("/api/v1/accounts", %{"id" => [a.id, Needle.UID.generate()]})
        |> json_response(200)

      assert Enum.map(response, & &1["id"]) == [a.id]
    end

    test "no ids answers an empty list", %{conn: conn} do
      assert conn |> get("/api/v1/accounts") |> json_response(200) == []
    end
  end
end
