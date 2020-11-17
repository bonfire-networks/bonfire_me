defmodule Bonfire.Me.Web.LoginView do
  use Bonfire.Web, [:view, Application.get_env(:bonfire_me, :templates_path)]

  alias Bonfire.Web.Layout.HeaderGuestLive
  alias Bonfire.Web.Layout.LogoHeaderLive
  alias Bonfire.Web.Layout.LoginLive
end
