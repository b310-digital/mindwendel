defmodule MindwendelWeb.ErrorView do
  use MindwendelWeb, :view

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  # def render("500.html", _assigns) do
  #   "Internal Server Error"
  # end

  def template_not_found(_template, assigns) do
    render("error_page.html", assigns)
  end
end
