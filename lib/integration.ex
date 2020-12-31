defmodule Bonfire.Me.Integration do

  def repo, do: Bonfire.Common.Config.get!(:repo_module)

  def mailer, do: Bonfire.Common.Config.get!(:mailer_module)

end
