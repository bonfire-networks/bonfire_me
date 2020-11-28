defmodule Bonfire.Me.AccessControl.Accesses do

  alias Bonfire.Data.AccessControl.Access

  defp repo, do: Application.get_env(:bonfire_me, :repo_module)

  def create(%{}=attrs) when not is_struct(attrs) do
    repo().insert(changeset(attrs))
  end

  def changeset(access \\ %Access{}, attrs) do
    Access.changeset(access, attrs)
  end

end
