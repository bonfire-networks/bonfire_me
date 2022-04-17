defmodule Bonfire.Me.Settings.LoadConfig do
  @moduledoc """
  Loads instance Settings from DB into Elixir's Config

  While this module is a GenServer, it is only responsible for querying the settings, putting them in Config, and then exits with :ignore having done so.
  """
  use GenServer, restart: :transient
  import Where

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
    {Bonfire.Common.Config.put(settings), Map.new(settings || [skip: "No settings loaded"])}
  end

end
