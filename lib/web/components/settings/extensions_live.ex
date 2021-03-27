defmodule Bonfire.Me.Web.SettingsLive.ExtensionsLive do
  use Bonfire.Web, :live_component

  @prefix "bonfire_"
  @prefix_data "bonfire_data_"

  require Logger
  # import Mix.Dep, only: [loaded: 1, format_dep: 1, format_status: 1, check_lock: 1]

  def update(assigns, socket) do

    deps = deps()
    #IO.inspect(List.first(deps))

    extensions = filter_bonfire(deps)
    other_deps = filter_bonfire(deps, false)

    schemas = filter_bonfire(extensions, true, @prefix_data)
    extensions = filter_bonfire(extensions, false, @prefix_data)
    #IO.inspect(List.first(extensions))

    {:ok, assign(socket,
      extensions: extensions,
      schemas: schemas,
      other_deps: other_deps
   ) }
  end

  @spec deps() :: list(Mix.Dep.t())
  defp deps() do
    {func, args} = loaded_deps_func_name()
    apply(Mix.Dep, func, args)
    # |> IO.inspect
  end

  defp loaded_deps_func_name() do
    if Keyword.has_key?(Mix.Dep.__info__(:functions), :cached) do
      {:cached, []}
    else
      {:loaded, [[]]}
    end
  end

  defp filter_bonfire(deps, only \\ true, prefix \\ @prefix) do
    Enum.filter(deps, fn
      %{app: name} ->
        case Atom.to_string(name) |> String.split(prefix) do
          [_, _] -> only
          _ -> !only
        end
      _ -> !only
    end)
  end

  defp get_version(%Mix.Dep{scm: Mix.SCM.Path}=dep), do: " (local fork based on "<>get_branch(dep)<>" "<>do_get_version(dep)<>")"
  defp get_version(dep), do: do_get_version(dep)

  defp do_get_version(%Mix.Dep{status: {:ok, version}}), do: version
  defp do_get_version(%Mix.Dep{requirement: version}), do: version
  defp do_get_version(_), do: ""

  defp get_branch(%{opts: opts}) when is_list(opts), do: get_branch(Enum.into(opts, %{}))
  defp get_branch(%{git: _, branch: branch}), do: branch
  defp get_branch(%{lock: {:git, _url, _, [branch: branch]}}), do: branch
  defp get_branch(dep), do: ""

  defp get_link(%{opts: opts}) when is_list(opts), do: get_link(Enum.into(opts, %{}))
  defp get_link(%{hex: hex}), do: "https://hex.pm/packages/#{hex}"
  defp get_link(%{lock: {:git, "https://github.com/"<>url, ref, [branch: branch]}}), do: "https://github.com/#{url}/compare/#{ref}...#{branch}"
  defp get_link(%{lock: {:git, url, _, [branch: branch]}}), do: "#{url}/tree/#{branch}"
  defp get_link(%{lock: {:git, url, _, _}}), do: url
  defp get_link(%{git: url, branch: branch}), do: "#{url}/tree/#{branch}"
  defp get_link(%{git: url}), do: url
  defp get_link(%{path: url}), do: "?path="<>url
  defp get_link(dep) do
    IO.inspect(dep)
    "#"
  end

end
