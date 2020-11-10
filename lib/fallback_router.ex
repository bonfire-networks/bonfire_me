defmodule Bonfire.Me.Web.FallbackRoutes do
  use Bonfire.WebPhoenix, :router

  alias Bonfire.Web.Routes.Helpers, as: Routes

  # include routes from CommonsPub extensions
  use Bonfire.Me.Web.Router

end
