defmodule Bonfire.Me.AccessControl.Grants do

  alias Bonfire.Data.AccessControl.Grant

  defp repo, do: Application.get_env(:bonfire_me, :repo_module)

  def create(%{}=attrs) when not is_struct(attrs) do
    repo().insert(changeset(attrs))
  end

  def changeset(access \\ %Grant{}, attrs) do
    Grant.changeset(access, attrs)
  end

end
