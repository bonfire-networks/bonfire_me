defmodule CommonsPub.Me.UseModule do

  defmacro __using__([module_key | [fun]]) do
    module = Application.get_env(:cpub_me, module_key)

    module = if Code.ensure_loaded?(module) do
      module
    else
      CommonsPub.Me.WebFallback
    end

      quote do
        use unquote(module), unquote(fun)
      end

  end

end
