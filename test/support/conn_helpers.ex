defmodule Bonfire.Me.Test.ConnHelpers do

  import ExUnit.Assertions
  import Plug.Conn
  import Phoenix.ConnTest

      import Bonfire.UI.Common.Testing.Helpers

  import Phoenix.LiveViewTest
  # alias CommonsPub.Accounts
  alias Bonfire.Data.Identity.Account
  alias Bonfire.Data.Identity.User

  @endpoint Bonfire.Common.Config.get!(:endpoint_module)

  ### conn

  def session_conn(conn \\ build_conn()), do: Plug.Test.init_test_session(conn, %{})


end
