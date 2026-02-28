defmodule Bonfire.Me.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest

      import Bonfire.UI.Common.Testing.Helpers

      import Phoenix.LiveViewTest, except: [open_browser: 1, open_browser: 2]

      import PhoenixTest

      use Bonfire.Common.Repo

      # The default endpoint for testing
      @endpoint Application.compile_env!(:bonfire, :endpoint_module)

      @moduletag :ui
    end
  end

  setup tags do
    Bonfire.Common.Test.Interactive.setup_test_repo(tags)

    {:ok, []}
  end
end
