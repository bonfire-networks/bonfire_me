defmodule Bonfire.Me.SensitiveActions do
  @moduledoc "Server-owned pending actions. Email tokens prove identity, while a separate confirmation executes a registered action."
  use Bonfire.Common.Repo
  import Ecto.Query
  alias Bonfire.Data.Identity.PendingAction
  alias Bonfire.Me.Accounts

  @request_lifetime_seconds 30 * 60
  @email_token_lifetime_seconds 10 * 60
  @verification_lifetime_seconds 5 * 60

  @doc """
  Resolves server-configured actions, never module names supplied by a request.

      iex> Bonfire.Me.SensitiveActions.resolve("unknown")
      {:error, :unknown_action}
  """
  def resolve(action) do
    registry = Bonfire.Common.Config.get([:bonfire_me, __MODULE__, :actions], %{
      "delete_account" => Bonfire.Me.SensitiveActions.DeleteAccount
    })
    case Map.fetch(registry, action) do
      {:ok, module} when is_atom(module) -> {:ok, module}
      _ -> {:error, :unknown_action}
    end
  end

  @doc "Creates an account-owned intent. The first supported action targets the account itself."
  def create(%{id: account_id} = account, action) do
    with {:ok, module} <- resolve(action),
         pending = %PendingAction{action: action, account_id: account_id, target_id: account_id},
         :ok <- module.authorize(%{account: account, pending: pending}) do
      pending
      |> PendingAction.changeset(expires_at: DateTime.add(DateTime.utc_now(), @request_lifetime_seconds))
      |> repo().insert()
    end
  end

  @doc "Deletes requests past their expiry, including consumed requests; active requests remain available."
  def prune_expired do
    now = DateTime.utc_now()

    {count, _} =
      from(pending in PendingAction, where: pending.expires_at <= ^now)
      |> repo().delete_all()

    {:ok, count}
  end

  @doc "Loads a pending action, rejecting malformed identifiers, expired and consumed requests."
  def fetch(id) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         %PendingAction{} = pending <- repo().get(PendingAction, id),
         :ok <- available(pending) do
      {:ok, pending}
    else
      _ -> {:error, :expired}
    end
  end

  @doc "Loads current account state and checks the action's authorization again."
  def context(pending) do
    with {:ok, module} <- resolve(pending.action),
         {:ok, account} <- Accounts.fetch_current(pending.account_id),
         context = %{pending: pending, account: account},
         :ok <- module.authorize(context) do
      {:ok, module, context}
    end
  end

  @doc "Issues a fresh hashed email proof, replacing earlier links without changing email-confirmation state."
  def issue_email(id, account_id) do
    locked(id, fn pending ->
      with :ok <- owner(pending, account_id),
           {:ok, _, context} <- context(pending),
           account = repo().preload(context.account, :email),
           %{email_address: address, confirmed_at: confirmed} when is_binary(address) and not is_nil(confirmed) <- account.email do
        token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
        updated = update!(pending, token_hash: hash(token), email_address: address,
          token_expires_at: DateTime.add(DateTime.utc_now(), @email_token_lifetime_seconds))
        {:ok, {updated, account, token}}
      else
        _ -> {:error, :not_allowed}
      end
    end)
  end

  @doc "Consumes an email proof once, without executing the action or authenticating any other browser."
  def redeem(id, token, current_account_id) when is_binary(token) do
    locked(id, fn pending ->
      with true <- is_nil(current_account_id) or current_account_id == pending.account_id,
           true <- is_binary(pending.token_hash) and Plug.Crypto.secure_compare(pending.token_hash, hash(token)),
           true <- future?(pending.token_expires_at),
           {:ok, _, context} <- context(pending),
           account = repo().preload(context.account, :email),
           %{email_address: address, confirmed_at: confirmed} when not is_nil(confirmed) <- account.email,
           true <- address == pending.email_address do
        clear_email_proof!(pending)
        {:ok, proof(pending)}
      else
        _ -> {:error, :invalid_link}
      end
    end)
  end
  def redeem(_, _, _), do: {:error, :invalid_link}

  @doc "Checks a password for the owning signed-in account. The caller must rate-limit attempts."
  def verify_password(id, account_id, password) when is_binary(password) do
    with {:ok, pending} <- fetch(id),
         :ok <- owner(pending, account_id),
         {:ok, _, _} <- context(pending),
         true <- Accounts.login_valid?(account_id, password) do
      {:ok, proof(pending)}
    else
      _ -> {:error, :invalid_credentials}
    end
  end
  def verify_password(_, _, _), do: {:error, :invalid_credentials}

  @doc "Checks trusted session proof. Anonymous cross-device proof is restricted to its pending action."
  def fresh?(proof, pending, current_account_id, now \\ System.system_time(:second))
  def fresh?(%{"account_id" => account_id, "at" => at} = proof, pending, current_account_id, now)
      when is_integer(at) do
    account_id == pending.account_id and now >= at and now - at < @verification_lifetime_seconds and
      (current_account_id == account_id or
         (is_nil(current_account_id) and proof["pending_id"] == pending.id))
  end
  def fresh?(_, _, _, _), do: false

  @doc "Executes once under a row lock. Enqueuing the action and consuming its intent share a transaction."
  def confirm(id, proof, current_account_id) do
    locked(id, fn pending ->
      with true <- fresh?(proof, pending, current_account_id),
           {:ok, module, context} <- context(pending),
           {:ok, result} <- module.execute(context) do
        clear_email_proof!(pending, consumed_at: DateTime.utc_now())
        {:ok, result}
      else
        false -> {:error, :needs_reauth}
        error -> error
      end
    end)
  end

  @doc "Cancels an intent for its owner or a browser with fresh proof."
  def cancel(id, proof, account_id) do
    locked(id, fn pending ->
      if account_id == pending.account_id or fresh?(proof, pending, account_id) do
        {:ok, clear_email_proof!(pending, consumed_at: DateTime.utc_now())}
      else
        {:error, :not_allowed}
      end
    end)
  end

  defp proof(pending), do: %{"account_id" => pending.account_id, "pending_id" => pending.id, "at" => System.system_time(:second)}
  defp owner(%{account_id: id}, id), do: :ok
  defp owner(_, _), do: {:error, :not_allowed}
  defp hash(token), do: :crypto.hash(:sha256, token)
  defp future?(%DateTime{} = time), do: DateTime.compare(time, DateTime.utc_now()) == :gt
  defp future?(_), do: false
  defp available(pending) do
    if is_nil(pending.consumed_at) and future?(pending.expires_at), do: :ok, else: {:error, :expired}
  end
  defp update!(pending, attrs), do: pending |> PendingAction.changeset(attrs) |> repo().update!()

  defp clear_email_proof!(pending, attrs \\ []) do
    update!(pending, [email_address: nil, token_hash: nil, token_expires_at: nil] ++ attrs)
  end

  defp locked(id, fun) do
    with {:ok, id} <- Ecto.UUID.cast(id) do
      repo().transaction(fn ->
        pending = repo().one(from p in PendingAction, where: p.id == ^id, lock: "FOR UPDATE")
        result = if pending, do: available(pending), else: {:error, :expired}
        with :ok <- result, {:ok, value} <- fun.(pending) do
          value
        else
          {:error, reason} -> repo().rollback(reason)
        end
      end)
    else
      _ -> {:error, :expired}
    end
  end
end
