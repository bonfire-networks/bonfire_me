defmodule Bonfire.Me.SensitiveActions do
  @moduledoc "Factor-based sudo: resolves opted-in action modules, computes which authentication factors an account must have fresh, and checks or stamps the session's factors map. Proof lives in the session; there is no server-side request state."

  use Bonfire.Common.Config
  alias Bonfire.Me.Accounts

  @factor_strength_default [
    # :totp,
    :password,
    :email
    # :sso
  ]

  @doc """
  Resolves a request-supplied module name, but only to modules that opted in by adopting the `Action` behaviour. `maybe_to_module` resolves existing atoms only, so no atoms are created.

      iex> Bonfire.Me.SensitiveActions.resolve("unknown")
      {:error, :unknown_action}
  """
  def resolve(action_param) do
    with module when is_atom(module) and not is_nil(module) <-
           Bonfire.Common.Types.maybe_to_module(action_param),
         true <- function_exported?(module, :__info__, 1),
         behaviours = List.wrap(module.__info__(:attributes)[:behaviour]),
         true <- Bonfire.Me.SensitiveActions.Action in behaviours do
      {:ok, module}
    else
      _ -> {:error, :unknown_action}
    end
  end

  @doc "Factors this account can complete, in configured strength order. The strength order is also the universe of considered factors."
  def available_factors(account) do
    Config.get([__MODULE__, :factor_strength], @factor_strength_default)
    |> Enum.filter(&factor_available?(&1, account))
  end

  defp factor_available?(:password, account),
    do: !passwordless_instance?() and Accounts.account_has_password?(account)

  defp factor_available?(:email, _account), do: true
  # TODO: :totp and :sso / {:sso, provider} join once their enrollment and challenge UIs exist
  defp factor_available?(_, _account), do: false

  # gated instances never offer password login, so the password factor is unavailable there regardless of stored hashes (Ghost provisions unknowable ones)
  defp passwordless_instance?, do: Accounts.passwordless_only?()

  @doc "Resolves an action module's factor requirement (instance config beating its `factors/0` default) to the concrete top-n list this account must have fresh."
  def required(module, account) do
    default = if function_exported?(module, :factors, 0), do: module.factors(), else: :any
    available = available_factors(account)

    case Config.get([module, :sudo_factors], default) do
      :any -> Enum.take(available, 1)
      {:any, n} when is_integer(n) and n > 0 -> Enum.take(available, n)
      :all -> available
      list when is_list(list) -> Enum.filter(available, &(&1 in list))
    end
  end

  @doc "Whether every required factor is fresh in the session's factors map (stamps are unix milliseconds). Future timestamps fail closed."
  def fresh?(factors_map, required) do
    window = Config.get([__MODULE__, :sudo_window], to_timeout(minute: 5))

    Enum.all?(required, fn factor ->
      with t when is_integer(t) <- factors_map[factor],
           {:ok, stamped} <- DateTime.from_unix(t, :millisecond) do
        !Bonfire.Common.DatesTimes.future?(stamped) and
          Bonfire.Common.DatesTimes.future?(DateTime.add(stamped, window, :millisecond))
      else
        _ -> false
      end
    end)
  end

  @doc "The strongest required factor not yet fresh, or :met."
  def next_challenge(factors_map, required) do
    Enum.find(required, :met, &(not fresh?(factors_map, [&1])))
  end

  @doc "Records an earned factor into the session's factors map (unix milliseconds), merging with whatever is already fresh."
  def stamp(factors_map, factor) do
    Map.put(factors_map || %{}, factor, System.system_time(:millisecond))
  end
end
