# SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.Me.Auth.BearerTokenTest do
  use Bonfire.Me.DataCase, async: true

  alias Bonfire.Me.Auth.BearerToken

  @salt "bonfire_test_salt_v1"

  test "sign/verify round-trip" do
    ids = {"account_id_123", "myusername"}
    token = BearerToken.sign(ids, salt: @salt)
    assert {:ok, ^ids} = BearerToken.verify(token, salt: @salt)
  end

  test "verify rejects tampered token" do
    token = BearerToken.sign({"id", "user"}, salt: @salt)
    assert {:error, _} = BearerToken.verify(token <> "x", salt: @salt)
  end

  test "verify respects max_age" do
    token = BearerToken.sign({"id", "user"}, salt: @salt)
    assert {:error, :expired} = BearerToken.verify(token, salt: @salt, max_age: 0)
  end

  test "tokens from different salts are not interchangeable" do
    token = BearerToken.sign("payload", salt: @salt)
    assert {:error, _} = BearerToken.verify(token, salt: "other_salt")
  end
end
