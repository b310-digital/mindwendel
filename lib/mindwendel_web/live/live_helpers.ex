defmodule MindwendelWeb.LiveHelpers do
  import Phoenix.LiveView.Helpers
  import MindwendelWeb.Gettext

  alias Mindwendel.Brainstormings.Brainstorming

  @doc """
  Renders a component inside the `MindwendelWeb.ModalComponent` component.

  The rendered modal receives a `:return_to` option to properly update
  the URL when the modal is closed.

  ## Examples

      <%= live_modal MindwendelWeb.IdeaLive.FormComponent,
        id: @idea.id || :new,
        action: @live_action,
        idea: @idea,
        return_to: Routes.idea_index_path(@socket, :index) %>
  """
  def live_modal(component, opts) do
    path = Keyword.fetch!(opts, :return_to)
    modal_opts = [id: :modal, return_to: path, component: component, opts: opts]
    live_component(MindwendelWeb.ModalComponent, modal_opts)
  end

  def uuid do
    Ecto.UUID.generate()
  end

  def brainstorming_available_until_full_text(brainstorming) do
    gettext("Brainstorming will be deleted %{days}",
      days: Brainstorming.brainstorming_available_until(brainstorming)
    )
  end

  def brainstorming_available_until(brainstorming) do
    Brainstorming.brainstorming_available_until(brainstorming)
  end
end
