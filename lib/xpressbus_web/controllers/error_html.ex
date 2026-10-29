defmodule XpressbusWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  Branded pages live in `error_html/`. They are embedded as HEEx function
  components (`not_found/1`, `internal_error/1`) and rendered here to an
  iodata-safe binary, then mapped from the status templates Phoenix asks for
  (`"404.html"`, `"500.html"`). Any status code without a custom page falls
  back to the plain status message.
  """
  use XpressbusWeb, :html

  embed_templates "error_html/*"

  def render("404.html", assigns), do: safe_html(not_found(assigns))
  def render("500.html", assigns), do: safe_html(internal_error(assigns))

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end

  defp safe_html(rendered) do
    {:safe, rendered |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()}
  end
end
