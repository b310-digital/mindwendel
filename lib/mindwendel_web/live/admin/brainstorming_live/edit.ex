defmodule MindwendelWeb.Admin.BrainstormingLive.Edit do
  use MindwendelWeb, :live_view

  alias Mindwendel.Brainstormings
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.IdeaLabelFactory
  alias Mindwendel.Brainstormings.IdeaLabel
  alias Mindwendel.Repo

  import Ecto.Query

  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket), do: Brainstormings.subscribe(id)

    brainstorming =
      Brainstormings.get_brainstorming_by!(%{admin_url_id: id})
      |> Repo.preload(
        labels:
          from(idea_label in IdeaLabel,
            order_by: idea_label.position_order,
            preload: [:idea_idea_labels]
          )
      )

    changeset = Brainstormings.change_brainstorming(brainstorming, %{})

    {
      :ok,
      socket
      |> assign(:page_title, "Admin")
      |> assign(:brainstorming, brainstorming)
      |> assign(:form, to_form(changeset))
    }
  end

  def handle_info(:reset_changeset, socket) do
    brainstorming = socket.assigns.brainstorming
    changeset = Brainstormings.change_brainstorming(brainstorming, %{})
    {:noreply, assign(socket, :form, to_form(changeset))}
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
          |> assign(:form, to_form(changeset))
          |> assign(:reset_changeset_timer_ref, reset_changeset_timer_ref)
          |> clear_flash()
        }

      {:error, changeset} ->
        cancel_changeset_timer(socket)

        {
          :noreply,
          socket
          |> assign(form: to_form(changeset))
          |> put_flash(:error, gettext("Your brainstorming was not saved."))
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
          |> assign(:form, to_form(Brainstorming.changeset(brainstorming, %{})))
          |> assign(:reset_changeset_timer_ref, reset_changeset_timer_ref)
          |> clear_flash()
        }

      {:error, changeset} ->
        cancel_changeset_timer(socket)

        {
          :noreply,
          socket
          |> assign(form: to_form(changeset))
          |> put_flash(:error, gettext("Your brainstorming was not saved."))
        }
    end
  end

  def handle_event("remove_idea_label", %{"value" => idea_label_id}, socket) do
    brainstorming = socket.assigns.brainstorming

    brainstorming_labels =
      brainstorming.labels
      |> Enum.map(fn label ->
        if label.id == idea_label_id do
          %{label | delete: true}
        else
          label
        end
      end)
      |> Enum.map(&Map.from_struct/1)

    case Brainstormings.update_brainstorming(brainstorming, %{labels: brainstorming_labels}) do
      {:ok, brainstorming} ->
        reset_changeset_timer_ref = reset_changeset_timer(socket)

        {
          :noreply,
          socket
          |> assign(:brainstorming, brainstorming)
          |> assign(:form, to_form(Brainstorming.changeset(brainstorming, %{})))
          |> assign(:reset_changeset_timer_ref, reset_changeset_timer_ref)
          |> clear_flash()
        }

      {:error, changeset} ->
        cancel_changeset_timer(socket)

        {
          :noreply,
          socket
          |> assign(form: to_form(changeset))
          |> put_flash(:error, gettext("Your brainstorming was not saved."))
        }
    end
  end

  def handle_event("empty", %{"value" => brainstorming_admin_url_id}, socket)
      when brainstorming_admin_url_id == socket.assigns.brainstorming.admin_url_id do
    brainstorming = socket.assigns.brainstorming

    Brainstormings.empty(brainstorming)

    {:noreply, push_navigate(socket, to: ~p"/brainstormings/#{brainstorming.id}")}
  end

  defp cancel_changeset_timer(socket) do
    if socket.assigns[:reset_changeset_timer_ref],
      do: Process.cancel_timer(socket.assigns.reset_changeset_timer_ref)

    socket.assigns[:reset_changeset_timer_ref]
  end

  defp reset_changeset_timer(socket) do
    cancel_changeset_timer(socket)

    # Reset changeset after five seconds in order to remove the save tooltip
    Process.send_after(self(), :reset_changeset, 5 * 1000)
  end
end
