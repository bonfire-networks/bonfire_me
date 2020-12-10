defmodule Bonfire.Me.Integration do

  def repo, do: Application.get_env(:bonfire_me, :repo_module)

  def mailer, do: Application.get_env(:bonfire_me, :mailer_module)

end
