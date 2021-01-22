defmodule MindwendelWeb.ErrorView do
  use MindwendelWeb, :view

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  # def render("500.html", _assigns) do
  #   "Internal Server Error"
  # end

  def render("400.html", assigns) do
    render("error_page.html", assigns)
  end

  def render("404.html", assigns) do
    render("error_page.html", assigns)
  end

  def render("500.html", assigns) do
    render("error_page.html", assigns)
  end

  def template_not_found(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
