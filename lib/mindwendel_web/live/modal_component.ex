defmodule MindwendelWeb.ModalComponent do
  use MindwendelWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class="modal fade show"
      tabindex="-1"
      phx-hook="Modal"
      phx-target={"##{ @myself }"}
      phx-page-loading
    >
      <div class={"modal-dialog #{assigns.opts[:modal_size]}"} role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title"><%= assigns.opts[:title] %></h5>
            <%= live_patch("", to: @return_to, class: "phx-modal-close btn-close") %>
          </div>
          <div class="modal-body">
            <%= live_component(@component, @opts) %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("close", _, socket) do
    {:noreply, push_patch(socket, to: socket.assigns.return_to)}
  end
end
