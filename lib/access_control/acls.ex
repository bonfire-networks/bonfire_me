defmodule Bonfire.Me.AccessControl.Acls do

  alias Bonfire.Data.AccessControl.Acl
  import Bonfire.Me.Integration

  def create(%{}=attrs) when not is_struct(attrs) do
    repo().insert(changeset(attrs))
  end

  def changeset(access \\ %Acl{}, attrs) do
    Acl.changeset(access, attrs)
  end

end
