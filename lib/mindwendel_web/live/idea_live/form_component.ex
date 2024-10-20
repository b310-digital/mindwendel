defmodule MindwendelWeb.IdeaLive.FormComponent do
  use MindwendelWeb, :live_component

  alias MIME
  alias Mindwendel.Ideas
  alias Mindwendel.Attachments
  alias Mindwendel.IdeaLabels

  @impl true
  def mount(socket) do
    {:ok,
     socket
     # max file size is 8mb by default
     |> allow_upload(:attachment,
       accept: Mindwendel.Attachment.whitelisted_file_extensions(),
       max_entries: 1
     )}
  end

  @impl true
  def update(%{idea: idea} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Ideas.change_idea(idea))
     end)}
  end

  @impl true
  def handle_event("validate", %{"idea" => idea_params}, socket) do
    changeset = Ideas.change_idea(socket.assigns.idea, idea_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"idea" => idea_params}, socket) do
    save_idea(socket, socket.assigns.action, idea_params)
  end

  def handle_event("delete_attachment", %{"id" => id}, socket) do
    %{current_user: current_user, brainstorming: brainstorming, idea: idea} = socket.assigns

    if has_moderating_or_ownership_permission(brainstorming, idea, current_user) do
      attachment = Attachments.get_attachment!(id)
      Attachments.delete_attachment(attachment)
    end

    {:noreply, assign(socket, form: to_form(Ideas.change_idea(idea)))}
  end

  defp save_idea(socket, :update, idea_params) do
    idea = Ideas.get_idea!(idea_params["id"])

    %{current_user: current_user, brainstorming: brainstorming} = socket.assigns

    if has_moderating_or_ownership_permission(brainstorming, idea, current_user) do
      idea_params_merged =
        idea_params
        |> Map.put("user_id", idea.user_id || current_user.id)
        |> Map.put("tmp_attachments", prepare_attachments(socket))

      case Ideas.update_idea(
             idea,
             idea_params_merged
           ) do
        {:ok, _idea} ->
          {:noreply,
           socket
           |> put_flash(:info, gettext("Idea updated"))
           |> push_patch(to: ~p"/brainstormings/#{brainstorming.id}")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    end
  end

  defp save_idea(socket, :new, idea_params) do
    idea_params_merged =
      idea_params
      |> Map.put("user_id", socket.assigns.current_user.id)
      |> Map.put(
        "idea_labels",
        IdeaLabels.get_idea_labels(socket.assigns.brainstorming.filter_labels_ids)
      )
      |> Map.put("tmp_attachments", prepare_attachments(socket))

    case Ideas.create_idea(idea_params_merged) do
      {:ok, _idea} ->
        {:ok, user} = update_username(socket.assigns.current_user, idea_params_merged["username"])
        send(self(), {:user_updated, user})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Idea created successfully"))
         |> push_patch(to: ~p"/brainstormings/#{idea_params_merged["brainstorming_id"]}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp update_username(current_user, username) do
    Mindwendel.Accounts.update_user(current_user, %{
      username: username
    })
  end

  defp prepare_attachments(socket) do
    files =
      consume_uploaded_entries(socket, :attachment, fn %{path: path}, entry ->
        # uploads do not have any file ending, which does not work with waffle. Therefore, we copy the file to have the proper file ending (either image or pdf)
        # use existing path but exchange the current filename with a uuid and the correct file extension based on the mime type
        filename = "#{entry.uuid}.#{mime_ext(entry.client_type)}"

        dest =
          path
          |> String.split("/")
          |> Enum.reverse()
          |> tl()
          |> Enum.reverse()
          |> Enum.concat([filename])
          |> Enum.join("/")

        File.cp!(path, dest)
        {:ok, %{path: dest, name: entry.client_name}}
      end)

    files
  end

  defp mime_ext(client_type) do
    List.first(MIME.extensions(client_type))
  end

  defp error_to_string(:too_large), do: gettext("The selected file is too large")
  defp error_to_string(:too_many_files), do: gettext("Too many files selected")
  defp error_to_string(:not_accepted), do: gettext("File type is not allowed")
end
