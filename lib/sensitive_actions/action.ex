defmodule Bonfire.Me.SensitiveActions.Action do
  @moduledoc "Contract for registered sensitive actions. Execution must use the same database transaction and defer external effects to a job."

  @type context :: %{
          account: %Bonfire.Data.Identity.Account{},
          pending: %Bonfire.Data.Identity.PendingAction{}
        }
  @type introduction_context :: %{account: %Bonfire.Data.Identity.Account{}, pending: nil}

  @type message :: %{title: String.t(), description: String.t()}
  @type description :: %{title: String.t(), description: String.t(), success: message()}

  @doc "Supplies localized confirmation and completion copy. The introduction receives pending: nil because opening a page must not create a request. Later calls receive the pending request; descriptions must support both stages."
  @callback describe(context() | introduction_context()) :: description()
  @doc "Checks whether the account and target permit this action. Creation supplies an unsaved pending request; later checks reload the account before calling."
  @callback authorize(context()) :: :ok | {:error, term()}
  @doc "Queues the operation in the current database transaction; success means queued, not completed."
  @callback execute(context()) :: {:ok, term()} | {:error, term()}
end
