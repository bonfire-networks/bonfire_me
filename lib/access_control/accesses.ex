defmodule Bonfire.Me.AccessControl.Accesses do

  alias Bonfire.Data.AccessControl.Access

  # from our fixtures

  def read_only_id, do: "THE0N1YACCESS1SREADACCESS1"
  def administer_id, do: "AT0TA1C0NTR010VERS0METH1NG"

  defp repo, do: Application.get_env(:bonfire_me, :repo_module)

  def create(%{}=attrs) when not is_struct(attrs) do
    repo().insert(changeset(attrs))
  end

  def changeset(access \\ %Access{}, attrs) do
    Access.changeset(access, attrs)
  end

end
