defmodule Bonfire.Me.SensitiveActions.Action do
  @moduledoc "Contract for sensitive actions gated by sudo verification. Adopting this behaviour is what opts a module in; request parameters can only resolve to adopters. Execution must re-authorize and defer external effects to a job."

  @type context :: %{account: %Bonfire.Data.Identity.Account{}, target_id: String.t() | nil}

  @type message :: %{title: String.t(), description: String.t()}
  @type description :: %{title: String.t(), description: String.t(), success: message()}

  @doc "Supplies localized confirmation and completion copy; may load the target read-only for display."
  @callback describe(context()) :: description()

  @doc "Re-authorizes against freshly loaded state and queues the operation; success means queued, not completed."
  @callback execute(context()) :: {:ok, term()} | {:error, term()}

  @doc "Code-default factor requirement; instances override it via the module's `:sudo_factors` config. Defaults to `:any` when not exported."
  @callback factors() :: :any | {:any, pos_integer()} | :all | [atom()]
  @optional_callbacks factors: 0
end
