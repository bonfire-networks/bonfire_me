defmodule Bonfire.Me.AccessControl.Accesses do

  alias Bonfire.Data.AccessControl.Access
  import Bonfire.Me.Integration
  import Ecto.Query

  def accesses do
    %{ read_only:  "THE0N1YACCESS1SREADACCESS1",
       administer: "AT0TA1C0NTR010VERS0METH1NG",
    }
  end

  def accesses_fixture do
    Enum.map(accesses(), fn {k, v} -> %{id: v} end)
  end

  def create(%{}=attrs) when not is_struct(attrs) do
    repo().insert(changeset(attrs))
  end

  def changeset(access \\ %Access{}, attrs) do
    Access.changeset(access, attrs)
  end

  def list, do: repo().all(from(u in Access))

end
