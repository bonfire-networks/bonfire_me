defmodule CommonsPub.Me.Web.EmailView do
  use CommonsPub.WebPhoenix, [:view, Application.get_env(:cpub_me, :templates_path)]
end
