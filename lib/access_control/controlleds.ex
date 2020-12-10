defmodule Bonfire.Me.AccessControl.Controlleds do

  alias Bonfire.Data.AccessControl.Controlled
  import Bonfire.Me.Integration

  def create(%{}=attrs) when not is_struct(attrs) do
    repo().insert(changeset(attrs))
  end

  def changeset(c \\ %Controlled{}, attrs) do
    Controlled.changeset(c, attrs)
  end

end
