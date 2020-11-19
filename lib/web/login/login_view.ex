defmodule Bonfire.Me.Web.LoginView do
  use Bonfire.Web, [:view, Application.get_env(:bonfire_me, :templates_path)]

  alias Bonfire.Web.Components.HeaderGuestLive
  alias Bonfire.Web.Components.LogoHeaderLive
  alias Bonfire.Web.Components.LoginLive
end
