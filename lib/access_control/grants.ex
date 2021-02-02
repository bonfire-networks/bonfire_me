defmodule Bonfire.Me.AccessControl.Grants do

  alias Bonfire.Data.AccessControl.Grant
  import Bonfire.Me.Integration

  def grants do
    %{ read_only:  "GRANT0N1YACCESS1SREADACCES"}
  end

  def create(%{}=attrs) when not is_struct(attrs) do
    repo().insert(changeset(attrs))
  end

  def changeset(access \\ %Grant{}, attrs) do
    Grant.changeset(access, attrs)
  end

end
