defmodule CommonsPub.Me.Web.EmailView do
  use CommonsPub.Core.Web, [:view, Application.get_env(:cpub_me, :templates_path)]
end
