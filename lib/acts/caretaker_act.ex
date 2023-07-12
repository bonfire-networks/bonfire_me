defmodule Bonfire.Me.Acts.Caretaker do
  @moduledoc """
  An act that deals with maintaining a `Caretaker` record for a changeset.

  During insertion, adds an associated insert if a caretaker can be found in the epic options.

  During deletion, ensures that the related record will be cleaned up.

  Epic Options (insert):
    * `:caretaker` - user that will take care of the post, falls back to `:current_user`
    * `:current_user` - user that will taker care of the post, fallback if `:caretaker` is not set.

  Act Options:
    * `:on` - key to find changeset, required.
  """

  alias Bonfire.Epics
  # alias Bonfire.Epics.Act
  alias Bonfire.Epics.Epic

  alias Ecto.Changeset
  import Epics
  use Arrows

  def run(epic, act) do
    on = act.options[:on]
    changeset = epic.assigns[on]
    current_user = epic.assigns[:options][:current_user]

    cond do
      epic.errors != [] ->
        maybe_debug(
          epic,
          act,
          length(epic.errors),
          "Skipping due to epic errors"
        )

        epic

      is_nil(on) or not is_atom(on) ->
        maybe_debug(epic, act, on, "Skipping due to `on` option")
        epic

      not is_struct(changeset) || changeset.__struct__ != Changeset ->
        maybe_debug(epic, act, changeset, "Skipping :#{on} due to changeset")
        epic

      changeset.action not in [:insert, :upsert, :delete] ->
        maybe_debug(
          epic,
          act,
          changeset.action,
          "Skipping, no matching action on changeset"
        )

        epic

      changeset.action in [:insert, :upsert] ->
        case epic.assigns[:options][:caretaker] do
          %{id: id} ->
            maybe_debug(epic, act, id, "Casting explicit caretaker")
            cast(epic, act, changeset, on, id)

          id when is_binary(id) ->
            maybe_debug(epic, act, id, "Casting explicit caretaker")
            cast(epic, act, changeset, on, id)

          nil ->
            case current_user do
              %{id: id} ->
                Epics.smart(
                  epic,
                  act,
                  current_user,
                  "Casting current user as caretaker #{id}"
                )

                cast(epic, act, changeset, on, id)

              id when is_binary(id) ->
                maybe_debug(epic, act, id, "Casting current user as caretaker")
                cast(epic, act, changeset, on, id)

              _other ->
                Epics.smart(
                  epic,
                  act,
                  current_user,
                  "Skipping because of current user"
                )

                epic
            end

          other ->
            Epics.smart(epic, act, other, "Invalid custom caretaker")
            epic
        end

      changeset.action == :delete ->
        # TODO: deletion
        epic
    end
  end

  defp cast(epic, _act, changeset, on, caretaker_id) do
    id = Pointers.Changesets.get_field(changeset, :id)

    changeset
    |> Changeset.cast(%{caretaker: %{id: id, caretaker_id: caretaker_id}}, [])
    |> Changeset.cast_assoc(:caretaker)
    |> Epic.assign(epic, on, ...)
  end
end
