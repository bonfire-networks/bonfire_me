defmodule Bonfire.Me.Web.SettingsLive.ExtensionsLive do
  use Bonfire.Web, :live_component

  def update(assigns, socket) do

    deps = deps()
  IO.inspect(List.first(deps))

    extensions = filter_bonfire(deps)
    other_deps = filter_bonfire(deps, false)


    {:ok, assign(socket,
      extensions: extensions,
      other_deps: other_deps
   ) }
  end

  @spec deps() :: list(Mix.Dep.t())
  defp deps() do
    func = loaded_deps_func_name()
    apply(Mix.Dep, func, [[]])
    # |> IO.inspect
  end

  defp loaded_deps_func_name() do
    if Keyword.has_key?(Mix.Dep.__info__(:functions), :load_on_environment) do
      :load_on_environment
    else
      :loaded
    end
  end

  defp filter_bonfire(deps, only \\ true) do
    Enum.filter(deps, fn
  %{app: name} ->
    case Atom.to_string(name) do
      "bonfire_"<>_ -> only
      _ -> !only
    end
  _ -> !only
end)
  end

  defp get_version(%Mix.Dep{status: {:ok, version}}), do: version
  defp get_version(%Mix.Dep{requirement: version}), do: version
  defp get_version(_), do: nil

  defp get_link(%{opts: opts}) when is_list(opts), do: get_link(Enum.into(opts, %{}))
  defp get_link(%{git: url}), do: url
  defp get_link(%{hex: hex}), do: "https://hex.pm/packages/#{hex}"
  defp get_link(_), do: "#"

end
