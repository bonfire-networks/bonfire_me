# SPDX-License-Identifier: AGPL-3.0-only
if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.Me.Web.MastoAccountDeleteTest do
    @moduledoc """
    Mastodon-compatible POST /api/v1/accounts/delete: the right password queues the deletion and answers 200, a wrong password answers 403 and queues nothing.

    Run with: just test extensions/bonfire_me/test/api/masto_account_delete_test.exs
    """

    use Bonfire.Me.ConnCase, async: false

    alias Bonfire.Me.Fake

    @moduletag :masto_api

    @password "correct horse battery staple 42"

    setup do
      account = Fake.fake_account!(%{credential: %{password: @password}})
      user = Fake.fake_user!(account)

      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:current_user_id, user.id)
        |> Plug.Conn.put_session(:current_account_id, account.id)
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn, user: user, account: account}
    end

    defp queued_deletion_ids do
      Oban.Testing.all_enqueued(Bonfire.Common.Repo, worker: Bonfire.Me.DeleteWorker)
      |> Enum.flat_map(& &1.args["ids"])
    end

    test "control: without a password it answers an error and queues nothing", %{
      conn: conn,
      user: user
    } do
      conn = post(conn, "/api/v1/accounts/delete", %{})

      assert conn.status in 400..499
      refute user.id in queued_deletion_ids()
    end

    test "the right password answers 200 and queues the deletion", %{conn: conn, user: user} do
      conn = post(conn, "/api/v1/accounts/delete", %{"password" => @password})

      assert conn.status == 200
      assert user.id in queued_deletion_ids()
    end

    test "a wrong password answers 403 and queues nothing", %{conn: conn, user: user} do
      conn = post(conn, "/api/v1/accounts/delete", %{"password" => "not the password"})

      assert conn.status == 403
      refute user.id in queued_deletion_ids()
    end
  end
end
