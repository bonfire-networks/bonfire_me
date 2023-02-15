defmodule Bonfire.Me.Acts.Creator do
  @moduledoc """
  An act that deals with maintaining a `Created` record for a changeset.

  During insertion, adds an associated insert if a creator can be found in the epic options.

  During deletion, ensures that the related record will be cleaned up.

  Epic Options (insert):
    * `:creator` - user that will create the post, falls back to `:current_user`
    * `:current_user` - user that will create the post, fallback if `:creator` is not set.

  Act Options:
    * `:on` - key to find changeset, required.
  """

  alias Bonfire.Epics
  # alias Bonfire.Epics.Act
  alias Bonfire.Epics.Epic

  alias Ecto.Changeset
  import Epics
  use Arrows

  # see module documentation
  @doc false
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

      changeset.action not in [:insert, :delete] ->
        maybe_debug(
          epic,
          act,
          changeset.action,
          "Skipping, no matching action on changeset"
        )

        epic

      changeset.action == :insert ->
        case epic.assigns[:options][:creator] do
          %{id: id} ->
            maybe_debug(epic, act, id, "Casting explicit creator")
            cast(epic, act, changeset, on, id)

          id when is_binary(id) ->
            maybe_debug(epic, act, id, "Casting explicit creator")
            cast(epic, act, changeset, on, id)

          nil ->
            case current_user do
              %{id: id} ->
                Epics.smart(
                  epic,
                  act,
                  current_user,
                  "Casting current user as creator #{id}"
                )

                cast(epic, act, changeset, on, id)

              id when is_binary(id) ->
                maybe_debug(epic, act, id, "Casting current user as creator")
                cast(epic, act, changeset, on, id)

              other ->
                Epics.smart(
                  epic,
                  act,
                  current_user,
                  "Skipping because of current_user"
                )

                epic
            end

          other ->
            Epics.smart(epic, act, other, "Invalid custom creator")
            epic
        end

      changeset.action == :delete ->
        # TODO: deletion
        epic
    end
  end

  defp cast(epic, act, changeset, on, id) do
    maybe_debug(epic, act, id, "Casting creator")

    changeset
    |> Changeset.cast(%{created: %{creator_id: id}}, [])
    |> Changeset.cast_assoc(:created)
    |> Epic.assign(epic, on, ...)
  end
end
