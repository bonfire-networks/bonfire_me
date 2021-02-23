defmodule Bonfire.Me.Web.SettingsLive.ExtensionDiffLive do
  use Bonfire.Web, {:live_view, [layout: {Bonfire.Web.LayoutView, "without_sidebar.html"}]}

  require Logger
  alias Bonfire.Common.Web.LivePlugs

  def mount(params, session, socket) do
    LivePlugs.live_plug params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      LivePlugs.StaticChanged,
      LivePlugs.Csrf,
      &mounted/3,
    ]
  end

  defp mounted(params, session, socket) do
    # necessary to avoid running it twice (and interupting an already-running diffing)
    case connected?(socket) do
      true -> mounted_connected(params, session, socket)
      false ->  {:ok,
        socket
        |> assign(
        page_title: "Loading...",
        diffs: []
        )}
    end
  end

  defp mounted_connected(params, session, socket) do
    # diff = generate_diff(package, repo_path)
    diffs = with {:ok, patches} <- generate_diff(:bonfire_me, "./forks/bonfire_me") do
      patches
    else
      {:error, error} ->
        Logger.error(inspect(error))
        []
      error ->
        Logger.error(inspect(error))
        []
    end
    # TODO: handle errors
    {:ok,
        socket
        |> assign(
        page_title: "Extension",
        diffs: diffs
        )}
  end

  def generate_diff(package, repo_path) do
    case repo_latest_diff(package, repo_path) do
      {:ok, diff} ->

        # IO.inspect(diff)
        # render_diff(diff)
        {:ok, diff}

      :error ->
        {:error, "Could not generate latest diff."}
    end
  catch
    :throw, {:error, :invalid_diff} ->
      {:error, "Invalid diff."}
  end

  defp render_diff(patch) do

    # IO.inspect(patch)
    Phoenix.View.render_to_iodata(Bonfire.Me.DiffRenderView, "diff_render.html", patch: patch)

  end

  defp render_diff_stream(package, repo_path, stream) do
    path = tmp_path("html-#{package}-")

    # TODO: figure out how to stream the data to LiveView as it becomes available, in which case use something like this instead of `render_diff`

    File.open!(path, [:write, :raw, :binary, :write_delay], fn file ->
      Enum.each(stream, fn
        {:ok, patch} ->

          html_patch =
            Phoenix.View.render_to_iodata(Bonfire.Me.DiffRenderView, "diff_render.html", patch: patch)

          IO.binwrite(file, html_patch)

        error ->
          Logger.error("Failed to parse diff stream of #{package} at #{repo_path} with: #{inspect(error)}")
          throw({:error, :invalid_diff})
      end)
    end)

    # path

    File.read(path)

  end

  def repo_latest_diff(package, repo_path) do
    path_diff = tmp_path("diff-#{package}-")

    with  :ok <- git_fetch(repo_path),
          :ok <- git_config(repo_path),
          :ok <- git_add_all(repo_path),
          :ok <- git_diff(repo_path, path_diff) do

      parse_repo_latest_diff(path_diff)

    else
      error ->
        Logger.error("Failed to create diff of #{inspect package} for #{repo_path} at #{path_diff} with: #{inspect(error)}")
        :error
    end
  end

  def parse_repo_latest_diff(path_diff) do
      File.read!(path_diff)
      |> GitDiff.parse_patch()
  end

  def analyse_repo_latest_diff_stream(path_diff) do
    # TODO: figure out how to stream the data to LiveView as it becomes available, in which case use this instead of `parse_repo_latest_diff`
    stream =
      File.stream!(path_diff, [:read_ahead])
      |> GitDiff.stream_patch()
      |> Stream.transform(
        fn -> :ok end,
        fn elem, :ok -> {[elem], :ok} end,
        fn :ok -> File.rm(path_diff) end
      )

    {:ok, stream}
  end

  def git_config(repo_path) do

  # Enable better diffing
    ["config", "core.attributesfile", "../../config/.gitattributes"]
    |> git!(repo_path)
  end

  def git_fetch(repo_path) do

  # Fetch remote data
    ["fetch", "--force", "--quiet"]
    # |> Kernel.++(tags_switch(opts[:tag]))
    |> git!(repo_path)
  end

  def git_add_all(repo_path) do

  # Add local changes for diffing purposes
    ["add", "."]
    |> git!(repo_path)
  end

  def git_diff(repo_path, path_output, extra_opt \\ "--cached") do
    git!([
        "-c",
        "core.quotepath=false",
        "-c",
        "diff.algorithm=histogram",
        "diff",
      #  "--no-index", # specify if we're diffing a repo or two paths
        extra_opt, # optionally diff staged changes (older git versions don't support the equivaled --staged)
        "--no-color",
        "--output=#{path_output}",
      ], repo_path)
  end

  def git!(args, repo_path \\ ".", into \\ default_into()) do
    Logger.info(inspect %{repo: repo_path, git: args, cwd: File.cwd()})

    File.cd!(repo_path, fn ->

      opts = cmd_opts(into: into, stderr_to_stdout: true)

      case System.cmd("git", args, opts) do
        {response, 0} ->
          IO.inspect(git_response: response)
          :ok

        {response, _} ->
          raise("Command \"git #{Enum.join(args, " ")}\" failed with reason: #{inspect response}")
      end
    end)
  end

  defp default_into() do
    case Mix.shell() do
      Mix.Shell.IO -> IO.stream(:stdio, :line)
      _ -> ""
    end
  end

  # Attempt to set the current working directory by default.
  # This addresses an issue changing the working directory when executing from
  # within a secondary node since file I/O is done through the main node.
  defp cmd_opts(opts) do
    case File.cwd() do
      {:ok, cwd} -> Keyword.put(opts, :cd, cwd)
      _ -> opts
    end
  end

  defp tmp_path(prefix) do
    random_string = Base.encode16(:crypto.strong_rand_bytes(4))
    Path.join([System.tmp_dir!(), prefix <> random_string])
  end
end
