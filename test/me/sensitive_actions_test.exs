defmodule Bonfire.Me.SensitiveActionsTest do
  use Bonfire.Me.DataCase, async: false
  use Repatch.ExUnit
  import Bonfire.Me.Fake
  alias Bonfire.Me.SensitiveActions, as: Actions
  alias Bonfire.Data.Identity.Credential
  doctest Bonfire.Me.SensitiveActions

  test "cleanup removes expired unused and consumed requests while preserving active ones" do
    account = fake_account!()
    {:ok, expired} = Actions.create(account, "delete_account")
    {:ok, {expired, _, _token}} = Actions.issue_email(expired.id, account.id)
    {:ok, consumed} = Actions.create(account, "delete_account")
    {:ok, _} = Actions.cancel(consumed.id, nil, account.id)
    {:ok, active} = Actions.create(account, "delete_account")
    {:ok, {_, _, token}} = Actions.issue_email(active.id, account.id)

    for pending <- [expired, consumed] do
      pending
      |> Ecto.Changeset.change(expires_at: DateTime.add(DateTime.utc_now(), -1))
      |> repo().update!()
    end

    assert :ok = Oban.Testing.perform_job(Bonfire.Me.SensitiveActions.PruneWorker, %{}, [])
    refute repo().get(Bonfire.Data.Identity.PendingAction, expired.id)
    refute repo().get(Bonfire.Data.Identity.PendingAction, consumed.id)
    assert {:ok, _} = Actions.fetch(active.id)
    assert {:ok, _} = Actions.redeem(active.id, token, nil)
    assert {:ok, 0} = Actions.prune_expired()
  end

  test "email proof is single-use and does not execute the pending action" do
    account = fake_account!()
    {:ok, pending} = Actions.create(account, "delete_account")
    {:ok, {_, _, token}} = Actions.issue_email(pending.id, account.id)
    assert {:ok, proof} = Actions.redeem(pending.id, token, nil)
    assert Actions.fresh?(proof, pending, nil)
    assert {:ok, _} = Actions.fetch(pending.id)
    assert {:error, :invalid_link} = Actions.redeem(pending.id, token, nil)
    refute Actions.fresh?(nil, pending, account.id)
  end

  test "a different signed-in account cannot redeem a link or consume it" do
    account = fake_account!()
    other = fake_account!()
    {:ok, pending} = Actions.create(account, "delete_account")
    {:ok, {_, _, token}} = Actions.issue_email(pending.id, account.id)
    assert {:error, :invalid_link} = Actions.redeem(pending.id, token, other.id)
    assert {:ok, _} = Actions.redeem(pending.id, token, nil)
  end

  test "proof expires at five minutes and cannot authorize a different account" do
    account = fake_account!()
    other = fake_account!()
    {:ok, pending} = Actions.create(account, "delete_account")
    proof = %{"account_id" => account.id, "pending_id" => pending.id, "at" => 1000}
    assert Actions.fresh?(proof, pending, nil, 1299)
    refute Actions.fresh?(proof, pending, nil, 1300)
    refute Actions.fresh?(proof, pending, nil, 999)
    refute Actions.fresh?(proof, pending, other.id, 1001)
    refute Actions.fresh?(proof, %{pending | id: Ecto.UUID.generate()}, nil, 1001)
  end

  test "confirmation requires proof and executes only once" do
    Oban.Testing.with_testing_mode(:manual, fn ->
      account = fake_account!()
      {:ok, pending} = Actions.create(account, "delete_account")
      assert {:error, :needs_reauth} = Actions.confirm(pending.id, nil, account.id)
      {:ok, {_, _, token}} = Actions.issue_email(pending.id, account.id)
      {:ok, proof} = Actions.redeem(pending.id, token, nil)
      assert {:ok, %Oban.Job{}} = Actions.confirm(pending.id, proof, nil)
      assert {:error, :expired} = Actions.confirm(pending.id, proof, nil)
    end)
  end

  test "changed targets are rejected at confirmation" do
    account = fake_account!()
    {:ok, pending} = Actions.create(account, "delete_account")
    {:ok, {_, _, token}} = Actions.issue_email(pending.id, account.id)
    {:ok, proof} = Actions.redeem(pending.id, token, nil)
    pending |> Ecto.Changeset.change(target_id: "different-target") |> repo().update!()
    assert {:error, :not_allowed} = Actions.confirm(pending.id, proof, nil)
  end

  test "expired links and cancelled intents cannot be used" do
    account = fake_account!()
    {:ok, pending} = Actions.create(account, "delete_account")
    {:ok, {pending, _, token}} = Actions.issue_email(pending.id, account.id)
    pending |> Ecto.Changeset.change(token_expires_at: DateTime.add(DateTime.utc_now(), -1)) |> repo().update!()
    assert {:error, :invalid_link} = Actions.redeem(pending.id, token, nil)
    assert {:ok, _} = Actions.cancel(pending.id, nil, account.id)
    assert {:error, :expired} = Actions.fetch(pending.id)
  end

  test "passwordless accounts reject password verification without crashing" do
    account = fake_account!()
    repo().delete_all(from c in Credential, where: c.id == ^account.id)
    {:ok, pending} = Actions.create(account, "delete_account")
    assert {:error, :invalid_credentials} = Actions.verify_password(pending.id, account.id, "made-up")
  end

  test "resending invalidates the previous link and changing email invalidates the replacement" do
    account = fake_account!()
    {:ok, pending} = Actions.create(account, "delete_account")
    {:ok, {_, _, first}} = Actions.issue_email(pending.id, account.id)
    {:ok, {_, _, replacement}} = Actions.issue_email(pending.id, account.id)
    assert {:error, :invalid_link} = Actions.redeem(pending.id, first, nil)
    account.email
    |> Ecto.Changeset.change(email_address: "changed-#{System.unique_integer([:positive])}@example.com")
    |> repo().update!()
    assert {:error, :invalid_link} = Actions.redeem(pending.id, replacement, nil)
  end

  test "redeeming and cancelling discard the no-longer-needed email proof metadata" do
    account = fake_account!()
    {:ok, pending} = Actions.create(account, "delete_account")
    {:ok, {_, _, token}} = Actions.issue_email(pending.id, account.id)
    {:ok, _} = Actions.redeem(pending.id, token, nil)
    stored = repo().get!(Bonfire.Data.Identity.PendingAction, pending.id)
    assert is_nil(stored.email_address)
    assert is_nil(stored.token_hash)
    assert is_nil(stored.token_expires_at)

    {:ok, _} = Actions.issue_email(pending.id, account.id)
    {:ok, _} = Actions.cancel(pending.id, nil, account.id)
    stored = repo().get!(Bonfire.Data.Identity.PendingAction, pending.id)
    assert is_nil(stored.email_address)
    assert is_nil(stored.token_hash)
    assert is_nil(stored.token_expires_at)
  end

  test "execution failure rolls back both the queued job and consumption" do
    Oban.Testing.with_testing_mode(:manual, fn ->
      account = fake_account!()
      {:ok, pending} = Actions.create(account, "delete_account")
      {:ok, {_, _, token}} = Actions.issue_email(pending.id, account.id)
      {:ok, proof} = Actions.redeem(pending.id, token, nil)
      before_count = repo().aggregate(Oban.Job, :count)
      Repatch.patch(Bonfire.Me.SensitiveActions.DeleteAccount, :execute, fn context ->
        {:ok, _} = Bonfire.Me.DeleteWorker.enqueue_delete(context.account)
        {:error, :simulated_failure_after_enqueue}
      end)
      assert {:error, :simulated_failure_after_enqueue} = Actions.confirm(pending.id, proof, nil)
      assert repo().aggregate(Oban.Job, :count) == before_count
      assert {:ok, _} = Actions.fetch(pending.id)
    end)
  end

  test "unknown actions and malformed identifiers fail closed" do
    assert {:error, :unknown_action} = Actions.resolve("Elixir.System")
    assert {:error, :expired} = Actions.fetch("bad")
    assert {:error, :expired} = Actions.confirm("bad", nil, nil)
  end
end
