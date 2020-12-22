defmodule Bonfire.Me.Integration do

  def repo, do: Bonfire.Common.Config.get_ext!(:bonfire_me, :repo_module)

  def mailer, do: Bonfire.Common.Config.get_ext!(:bonfire_me, :mailer_module)

end
