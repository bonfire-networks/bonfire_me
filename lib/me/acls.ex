defmodule Bonfire.Me.Acls do

  alias Ecto.Changeset
  alias Bonfire.Boundaries.Acls

  def cast(changeset, creator, preset) do
    base = base_acls(preset)
    grants = reply_to_grants(changeset preset) ++ mentions_grants(mentions, preset)
    acl = case grants do
      [] ->
        changeset
        |> Changeset.cast(%{controlled: base})
        |> Changeset.cast_assoc(:controlled)
      _ ->
        # TODO: cast a new acl. this is slightly tricky because we
        # need to insert the acl with cast_assoc(:acl) while taking the rest
        # of the controlleds from the base maps
        changeset
        |> Changeset.cast(%{controlled: base})
        |> Changeset.cast_assoc(:controlled)
    end
  end

  # when the user picks a preset, this maps to a set of base acls
  defp base_acls(preset) do
    acls = case preset do
      "public" -> [:guests_may_see, :locals_may_reply, :i_may_administer]
      "local"  -> [:locals_may_reply, :i_may_administer]
      _        -> [:i_may_administer]
    end
    |> Enum.map(&(%{acl_id: Acls.get_id!(&1)}))
  end

  defp reply_to_grants(changeset, preset) do
    if preset == "public" do
      # TODO look up
      []
    else
      []
    end
  end

  defp mentions_grants(mentions, preset) do
    # TODO look up
    []
  end

end
