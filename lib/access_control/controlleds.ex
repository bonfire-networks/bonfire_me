defmodule Bonfire.Me.AccessControl.Controlleds do

  alias Bonfire.Data.AccessControl.Controlled

  defp repo, do: Application.get_env(:bonfire_me, :repo_module)

  def create(%{}=attrs) when not is_struct(attrs) do
    repo().insert(changeset(attrs))
  end

  def changeset(c \\ %Controlled{}, attrs) do
    Controlled.changeset(c, attrs)
  end

end
