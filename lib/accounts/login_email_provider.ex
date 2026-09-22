defmodule Bonfire.Me.LoginEmailProvider do
  @moduledoc """
  Behaviour for extensions that can recognise a login email from an external source and bootstrap a local Bonfire account+user for it.

  Implement this behaviour and declare `@behaviour Bonfire.Me.LoginEmailProvider` in your module — it will be auto-discovered at startup via
  `Bonfire.Common.ExtensionBehaviour`.

  Called from `Bonfire.UI.Me.ForgotPasswordController.create/2` via `ensure/1` when `Accounts.get_by_email/1` returns `nil`. Providers may also implement `reconcile_account/2` to repair an externally linked, profileless local account before its magic link is issued.

  Providers must NEVER raise or leak membership status to callers — the outer flow is deliberately neutral to avoid becoming an email-existence oracle.
  """
  @behaviour Bonfire.Common.ExtensionBehaviour
  use Bonfire.Common.Utils, only: []
  import Untangle

  @doc """
  Attempts to provision a local account+user for `email` from an external
  source.

  Return values:

    * `{:ok, term()}` — provisioned (or already present). The caller
      re-fetches the local account and proceeds with sending the magic
      link.
    * `:no_match` — this provider does not recognise `email`. Caller
      should try the next provider.
    * `{:error, term()}` — upstream failure. Caller logs and tries the
      next provider; the error is never surfaced to the end user.
  """
  @callback ensure_account(email :: String.t()) ::
              {:ok, term()} | :no_match | {:error, term()}

  @doc """
  Optionally reconciles a profileless local account with the provider's external identity.

  Unlike `ensure/1`, the reconciliation dispatcher has no registration-hint side effect: the local account already exists and will receive the normal neutral magic-link response even when every provider declines.
  """
  @callback reconcile_account(email :: String.t(), account :: term()) ::
              {:ok, term()} | :no_match | {:error, term()}

  @optional_callbacks reconcile_account: 2

  def app_modules(), do: Bonfire.Common.ExtensionBehaviour.behaviour_app_modules(__MODULE__)

  @spec modules() :: [atom]
  def modules(), do: Bonfire.Common.ExtensionBehaviour.behaviour_modules(__MODULE__)

  @doc """
  Iterates all discovered providers for `email`, returning on the first
  `:ok`. Returns `:no_match` if every provider declines or errors.

  A registration hint is sent only when every provider explicitly returns
  `:no_match`; provider failures suppress the hint so an upstream outage does
  not incorrectly direct existing users to create another account.
  """
  @spec ensure(String.t()) :: {:ok, term()} | :no_match
  def ensure(email), do: ensure(modules(), email)

  @doc false
  @spec ensure([module()], String.t()) :: {:ok, term()} | :no_match
  def ensure(providers, email) when is_list(providers) and is_binary(email) and email != "" do
    {result, provider_failed?} =
      Enum.reduce_while(providers, {:no_match, false}, fn provider, {acc, provider_failed?} ->
        case safe_call(provider, email) do
          {:ok, _} = ok ->
            {:halt, {ok, provider_failed?}}

          :no_match ->
            {:cont, {acc, provider_failed?}}

          {:error, reason} ->
            {:cont, {log_and_continue(provider, reason, acc), true}}
        end
      end)

    if result == :no_match and not provider_failed?, do: maybe_send_registration_hint(email)
    result
  end

  def ensure(_, _), do: :no_match

  @doc "Runs optional provider reconciliation for a profileless local account."
  @spec reconcile(String.t(), term()) :: {:ok, term()} | :no_match
  def reconcile(email, account), do: reconcile(modules(), email, account)

  @doc false
  @spec reconcile([module()], String.t(), term()) :: {:ok, term()} | :no_match
  def reconcile(providers, email, account)
      when is_list(providers) and is_binary(email) and email != "" and not is_nil(account) do
    Enum.reduce_while(providers, :no_match, fn provider, acc ->
      if function_exported?(provider, :reconcile_account, 2) do
        case safe_reconcile(provider, email, account) do
          {:ok, _} = ok -> {:halt, ok}
          :no_match -> {:cont, acc}
          {:error, reason} -> {:cont, log_and_continue(provider, reason, acc)}
        end
      else
        {:cont, acc}
      end
    end)
  end

  def reconcile(_, _, _), do: :no_match

  defp maybe_send_registration_hint(email) do
    with url when is_binary(url) and url != "" <-
           Bonfire.Common.Config.get([:bonfire_ui_me, :login, :external_signup_url]),
         mailer when not is_nil(mailer) <- Bonfire.Me.Mails.mailer() do
      Bonfire.Me.Mails.registration_hint(url)
      |> mailer.send_now(email)
    end
  end

  defp safe_call(provider, email) do
    provider.ensure_account(email)
  rescue
    e ->
      error(e, "login email provider #{inspect(provider)} raised — treating as :no_match")
      {:error, e}
  catch
    kind, reason ->
      error(
        {kind, reason},
        "login email provider #{inspect(provider)} failed — treating as :no_match"
      )

      {:error, {kind, reason}}
  end

  defp safe_reconcile(provider, email, account) do
    provider.reconcile_account(email, account)
  rescue
    e ->
      error(
        e,
        "login email provider #{inspect(provider)} reconciliation raised — treating as :no_match"
      )

      {:error, e}
  catch
    kind, reason ->
      error(
        {kind, reason},
        "login email provider #{inspect(provider)} reconciliation failed — treating as :no_match"
      )

      {:error, {kind, reason}}
  end

  defp log_and_continue(provider, reason, acc) do
    warn(reason, "login email provider #{inspect(provider)} returned an error")
    acc
  end
end
