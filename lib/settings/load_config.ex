defmodule Bonfire.Me.Settings.LoadInstanceConfig do
  @moduledoc """
  Loads instance Settings from DB into Elixir's Config

  While this module is a GenServer, it is only responsible for querying the settings, putting them in Config, and then exits with :ignore having done so.
  """
  use GenServer, restart: :transient
  require Logger

  @spec start_link(ignored :: term) :: GenServer.on_start()
  @doc "Populates the global cache with table data via introspection."
  def start_link(_), do: GenServer.start_link(__MODULE__, [])

  # GenServer callback

  @doc false
  def init(_) do
    if Code.ensure_loaded?(:telemetry),
      do: :telemetry.span([:settings, :load_config], %{}, &load_config/0),
      else: load_config()

    :ignore
  end

  def load_config() do
    settings = Bonfire.Me.Settings.load_instance_settings()

    if settings do
      Logger.info("Loaded instance Settings were loaded into the app's Config")

      put = Bonfire.Common.Config.put(settings)

      # generate an updated reverse router based on extensions that are enabled/disabled
      Bonfire.Common.Extend.generate_reverse_router!()

      {put, Map.new(settings)}
    else
      Logger.info("No instance Settings to load into Config")
      {:ok, %{skip: "No settings loaded"}}
    end
  end
end
