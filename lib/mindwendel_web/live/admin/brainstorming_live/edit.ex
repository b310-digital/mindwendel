defmodule MindwendelWeb.Admin.BrainstormingLive.Edit do
  alias Mindwendel.Brainstormings
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.IdeaLabelFactory
  alias Mindwendel.Brainstormings.IdeaLabel
  alias Mindwendel.Repo

  import Ecto.Query

  use MindwendelWeb, :live_view

  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket), do: Brainstormings.subscribe(id)

    brainstorming =
      Brainstormings.get_brainstorming_by!(%{admin_url_id: id})
      |> Repo.preload(labels: from(idea_label in IdeaLabel, order_by: idea_label.position_order))

    changeset = Brainstormings.change_brainstorming(brainstorming, %{})

    {
      :ok,
      socket
      |> assign(:brainstorming, brainstorming)
      |> assign(:changeset, changeset)
    }
  end

  def handle_info(:reset_changeset, socket) do
    brainstorming = socket.assigns.brainstorming
    changeset = Brainstormings.change_brainstorming(brainstorming, %{})

    {
      :noreply,
      socket
      |> assign(:changeset, changeset)
    }
  end

  def handle_params(_unsigned_params, uri, socket),
    do: {:noreply, assign(socket, uri: URI.parse(uri))}

  def handle_event("save", %{"brainstorming" => brainstorming_params}, socket) do
    brainstorming =
      Brainstormings.get_brainstorming_by!(%{
        admin_url_id: socket.assigns.brainstorming.admin_url_id
      })
      |> Repo.preload(labels: from(idea_label in IdeaLabel, order_by: idea_label.position_order))

    changeset = Brainstorming.changeset(brainstorming, brainstorming_params)

    case Brainstormings.update_brainstorming(brainstorming, brainstorming_params) do
      {:ok, brainstorming_updated} ->
        reset_changeset_timer_ref = reset_changeset_timer(socket)

        {
          :noreply,
          socket
          |> assign(:brainstorming, brainstorming_updated)
          |> assign(:changeset, changeset)
          |> assign(:reset_changeset_timer_ref, reset_changeset_timer_ref)
        }

      {:error, changeset} ->
        {
          :noreply,
          socket
          |> assign(changeset: changeset)
        }
    end
  end

  def handle_event("add_idea_label", _params, socket) do
    brainstorming = socket.assigns.brainstorming

    idea_label_new = IdeaLabelFactory.build_idea_label(brainstorming)

    brainstorming_labels =
      (brainstorming.labels ++
         [
           %{
             idea_label_new
             | position_order: length(brainstorming.labels) + 1
           }
         ])
      |> Enum.map(&Map.from_struct/1)

    case Brainstormings.update_brainstorming(brainstorming, %{labels: brainstorming_labels}) do
      {:ok, brainstorming} ->
        reset_changeset_timer_ref = reset_changeset_timer(socket)

        {
          :noreply,
          socket
          |> assign(:brainstorming, brainstorming)
          |> assign(:changeset, Brainstorming.changeset(brainstorming, %{}))
          |> assign(:reset_changeset_timer_ref, reset_changeset_timer_ref)
          |> put_flash(:info, gettext("Your brainstorming was successfully updated."))
        }

      {:error, changeset} ->
        {
          :noreply,
          socket
          |> assign(changeset: changeset)
        }
    end
  end

  def handle_event("remove_idea_label", %{"value" => idea_label_id}, socket) do
    brainstorming = socket.assigns.brainstorming

    brainstorming_labels =
      Enum.map(
        brainstorming.labels,
        fn label ->
          if label.id == idea_label_id do
            %{label | delete: true}
          else
            label
          end
        end
      )
      |> Enum.map(&Map.from_struct/1)

    case Brainstormings.update_brainstorming(brainstorming, %{labels: brainstorming_labels}) do
      {:ok, brainstorming} ->
        reset_changeset_timer_ref = reset_changeset_timer(socket)

        {
          :noreply,
          socket
          |> assign(:brainstorming, brainstorming)
          |> assign(:changeset, Brainstorming.changeset(brainstorming, %{}))
          |> assign(:reset_changeset_timer_ref, reset_changeset_timer_ref)
          |> put_flash(:info, gettext("Your brainstorming was successfully updated."))
        }

      {:error, changeset} ->
        {
          :noreply,
          socket
          |> assign(changeset: changeset)
        }
    end
  end

  def brainstorming_available_until(brainstorming) do
    Timex.shift(brainstorming.inserted_at,
      days:
        Application.fetch_env!(:mindwendel, :options)[:feature_brainstorming_removal_after_days]
    )
  end

  defp reset_changeset_timer(socket) do
    if socket.assigns[:reset_changeset_timer_ref],
      do: Process.cancel_timer(socket.assigns.reset_changeset_timer_ref)

    # Reset changeset after five seconds in order to remove the save tooltip
    Process.send_after(self(), :reset_changeset, 5 * 1000)
  end
end
