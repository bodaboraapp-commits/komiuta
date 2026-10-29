defmodule XpressbusWeb.AdminHTML do
  @moduledoc """
  This module contains pages rendered by AdminController.

  See the `admin_html` directory for all templates available.
  """
  use XpressbusWeb, :html

  embed_templates "admin_html/*"
end
