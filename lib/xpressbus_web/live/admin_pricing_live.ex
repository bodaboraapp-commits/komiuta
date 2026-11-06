defmodule XpressbusWeb.AdminPricingLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.AdminComponents

  alias Xpressbus.Bookings.PricingSettings

  def mount(_params, session, socket) do
    if session["admin_id"] do
      settings = PricingSettings.get()

      {:ok,
       socket
       |> assign(:page_title, "Pricing & Fees")
       |> assign(:active_tab, "pricing")
       |> assign(:sidebar_collapsed, false)
       |> assign(:bus_expanded, false)
       |> assign(:chyllz_expanded, false)
       |> assign(:settings_expanded, true)
       |> assign(:settings, settings)
       |> assign(:form, form_for_settings(settings))}
    else
      {:ok, Phoenix.LiveView.redirect(socket, to: ~p"/admin/login")}
    end
  end

  def handle_event("validate", %{"pricing" => params}, socket) do
    changeset =
      PricingSettings.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: :pricing))}
  end

  def handle_event("save", %{"pricing" => params}, socket) do
    case PricingSettings.update(params) do
      {:ok, settings} ->
        {:noreply,
         socket
         |> assign(:settings, settings)
         |> assign(:form, form_for_settings(settings))
         |> put_flash(:info, "Pricing settings saved. New bookings will use these values.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(Map.put(changeset, :action, :validate), as: :pricing))
         |> put_flash(:error, "Please correct the highlighted fields.")}

      {:error, _reason} ->
        {:noreply,
         put_flash(socket, :error, "Could not save pricing settings. Please try again.")}
    end
  end

  defp form_for_settings(%PricingSettings{} = settings) do
    form_for_settings(%{
      convenience_fee: settings.convenience_fee,
      tax_rate: settings.tax_rate
    })
  end

  defp form_for_settings(settings) when is_map(settings) do
    settings
    |> PricingSettings.changeset()
    |> to_form(as: :pricing)
  end
end
