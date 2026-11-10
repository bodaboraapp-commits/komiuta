defmodule XpressbusWeb.TripManageLive do
  use XpressbusWeb, :live_view

  alias Xpressbus.{Accounts, Itineraries, Tickets, TripFinances}

  @tabs [
    {"expenses", "Expenses", "payments"},
    {"meals", "Meals & Food", "restaurant"},
    {"summary", "Summary", "category"},
    {"places", "Visited Places", "history"}
  ]

  @expense_categories ["Food", "Transport", "Stay", "Activities", "Shopping", "Other"]

  @impl true
  def mount(%{"ticket_id" => ticket_id}, session, socket) do
    case load_user(session) do
      nil ->
        {:ok, redirect(socket, to: "/user/login")}

      user ->
        case Tickets.get_ticket(ticket_id) do
          nil ->
            {:ok, redirect(socket, to: "/dashboard")}

          ticket ->
            if owns_ticket?(user, ticket) do
              {:ok, start_manage(socket, user, ticket_manage_context(ticket))}
            else
              {:ok, redirect(socket, to: "/dashboard")}
            end
        end
    end
  end

  @impl true
  def mount(%{"saved_itinerary_id" => saved_itinerary_id}, session, socket) do
    case load_user(session) do
      nil ->
        {:ok, redirect(socket, to: "/user/login")}

      user ->
        case Itineraries.get_for_user(user, saved_itinerary_id) do
          nil ->
            {:ok, redirect(socket, to: "/dashboard?tab=chyllz")}

          saved_itinerary ->
            {:ok, start_manage(socket, user, itinerary_manage_context(saved_itinerary))}
        end
    end
  end

  defp start_manage(socket, user, context) do
    finance_scope = TripFinances.scope(user, context.kind, context.finance_id)
    expenses = TripFinances.list_expenses(finance_scope)
    budget = TripFinances.get_budget(finance_scope)

    socket
    |> assign(:page_title, "Manage itinerary — #{context.trip.title}")
    |> assign(:page_robots, "noindex,nofollow")
    |> assign(:current_user, user.phone)
    |> assign(:user, user)
    |> assign(:finance_scope, finance_scope)
    |> assign(:tabs, @tabs)
    |> assign(:active_tab, "expenses")
    |> assign(:categories, @expense_categories)
    |> assign(:expenses, expenses)
    |> assign(:budget, budget)
    |> assign(:budget_input, "")
    |> assign(:budget_saved, false)
    |> assign(:editing_expense_id, nil)
    |> assign(:pending_delete, nil)
    |> assign(:undo_expense, nil)
    |> assign(:budget_form, false)
    |> assign(:expense_form, false)
    |> assign(:expense_category, "Food")
    |> assign(:error, nil)
    |> assign(:trip, context.trip)
    |> assign(:back_path, context.back_path)
    |> assign(:back_label, context.back_label)
    |> assign(:view_path, context.view_path)
    |> assign(:view_label, context.view_label)
    |> assign_metrics()
  end

  defp ticket_manage_context(ticket) do
    %{
      kind: :ticket,
      finance_id: ticket.ticket_id,
      trip: trip_meta(ticket),
      back_path: "/dashboard",
      back_label: "Back to Trips",
      view_path: "/tickets?ticket_id=#{ticket.ticket_id}",
      view_label: "View ticket"
    }
  end

  defp itinerary_manage_context(saved_itinerary) do
    %{
      kind: :saved,
      finance_id: saved_itinerary.id,
      trip: itinerary_meta(saved_itinerary),
      back_path: "/dashboard?tab=chyllz",
      back_label: "Back to itineraries",
      view_path: "/trip/build-with-ai?saved=#{saved_itinerary.id}",
      view_label: "View itinerary"
    }
  end

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    if tab in Enum.map(@tabs, &elem(&1, 0)) do
      {:noreply, assign(socket, :active_tab, tab)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_budget", _params, socket) do
    budget_form = not socket.assigns.budget_form

    {:noreply,
     socket
     |> assign(:budget_form, budget_form)
     |> assign(:budget_input, if(budget_form, do: amount_input(socket.assigns.budget), else: ""))
     |> assign(:budget_saved, false)}
  end

  def handle_event("toggle_expense", _params, socket) do
    {:noreply, assign(socket, :expense_form, not socket.assigns.expense_form)}
  end

  def handle_event("autosave_budget", %{"budget" => %{"amount" => amount}}, socket) do
    socket = assign(socket, :budget_input, to_string(amount || ""))

    case parse_amount(amount) do
      {:ok, value} ->
        case TripFinances.set_budget(socket.assigns.finance_scope, value) do
          {:ok, stored_budget} ->
            {:noreply,
             socket
             |> assign(:budget, stored_budget)
             |> assign(:budget_saved, true)
             |> assign(:error, nil)
             |> assign_metrics()}

          {:error, _changeset} ->
            {:noreply, socket}
        end

      :error ->
        {:noreply, assign(socket, :budget_saved, false)}
    end
  end

  def handle_event("save_budget", %{"budget" => %{"amount" => amount}}, socket) do
    case parse_amount(amount) do
      {:ok, value} ->
        case TripFinances.set_budget(socket.assigns.finance_scope, value) do
          {:ok, stored_budget} ->
            {:noreply,
             socket
             |> assign(:budget, stored_budget)
             |> assign(:budget_form, false)
             |> assign(:budget_saved, false)
             |> assign(:error, nil)
             |> assign_metrics()}

          {:error, _changeset} ->
            {:noreply, assign(socket, :error, "Enter a valid budget amount.")}
        end

      :error ->
        {:noreply, assign(socket, :error, "Enter a valid budget amount.")}
    end
  end

  def handle_event("save_expense", params, socket) do
    attrs = Map.get(params, "expense", %{})
    amount = parse_amount(attrs["amount"])
    label = String.trim(to_string(attrs["label"] || ""))
    category = if attrs["category"] in @expense_categories, do: attrs["category"], else: "Other"

    cond do
      amount == :error ->
        {:noreply, assign(socket, :error, "Enter a valid expense amount.")}

      label == "" ->
        {:noreply, assign(socket, :error, "Add a short description for this expense.")}

      true ->
        {:ok, value} = amount

        attrs = %{
          label: label,
          category: category,
          amount: value,
          spent_on: Date.utc_today()
        }

        case TripFinances.add_expense(socket.assigns.finance_scope, attrs) do
          {:ok, _expense} ->
            {:noreply,
             socket
             |> assign(:expenses, TripFinances.list_expenses(socket.assigns.finance_scope))
             |> assign(:expense_form, false)
             |> assign(:error, nil)
             |> assign_metrics()}

          {:error, _changeset} ->
            {:noreply, assign(socket, :error, "Could not save that expense.")}
        end
    end
  end

  def handle_event("edit_expense", %{"id" => id}, socket) do
    {:noreply, assign(socket, :editing_expense_id, to_string(id))}
  end

  def handle_event("cancel_expense_edit", _params, socket) do
    {:noreply, assign(socket, :editing_expense_id, nil)}
  end

  def handle_event("autosave_expense", %{"expense_id" => id, "expense" => attrs}, socket) do
    {:noreply, persist_expense_edit(socket, id, attrs, true)}
  end

  def handle_event("save_expense_edit", %{"expense_id" => id, "expense" => attrs}, socket) do
    {:noreply, persist_expense_edit(socket, id, attrs, false)}
  end

  def handle_event("confirm_delete_expense", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.expenses, &(to_string(&1.id) == to_string(id))) do
      nil ->
        {:noreply, socket}

      expense ->
        {:noreply,
         assign(socket, :pending_delete, %{
           id: expense.id,
           label: expense.label,
           amount_label: money(expense.amount)
         })}
    end
  end

  def handle_event("cancel_delete_expense", _params, socket) do
    {:noreply, assign(socket, :pending_delete, nil)}
  end

  def handle_event("delete_expense", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.expenses, &(to_string(&1.id) == to_string(id))) do
      nil ->
        {:noreply, assign(socket, :pending_delete, nil)}

      expense ->
        :ok = TripFinances.delete_expense(socket.assigns.finance_scope, expense.id)

        token = System.unique_integer([:positive])
        Process.send_after(self(), {:expire_undo_expense, token}, 8_000)

        {:noreply,
         socket
         |> assign(:expenses, TripFinances.list_expenses(socket.assigns.finance_scope))
         |> assign(:pending_delete, nil)
         |> assign(:editing_expense_id, nil)
         |> assign(:undo_expense, Map.put(expense, :token, token))
         |> assign_metrics()}
    end
  end

  def handle_event("undo_delete_expense", _params, socket) do
    case socket.assigns.undo_expense do
      nil ->
        {:noreply, socket}

      expense ->
        attrs = %{
          label: expense.label,
          category: expense.category,
          amount: expense.amount,
          spent_on: expense.date
        }

        case TripFinances.add_expense(socket.assigns.finance_scope, attrs) do
          {:ok, _expense} ->
            {:noreply,
             socket
             |> assign(:expenses, TripFinances.list_expenses(socket.assigns.finance_scope))
             |> assign(:undo_expense, nil)
             |> assign_metrics()}

          {:error, _changeset} ->
            {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_info({:expire_undo_expense, token}, socket) do
    socket =
      case socket.assigns[:undo_expense] do
        %{token: ^token} -> assign(socket, :undo_expense, nil)
        _other -> socket
      end

    {:noreply, socket}
  end

  defp assign_metrics(socket) do
    expenses = socket.assigns.expenses
    budget = socket.assigns.budget
    spent = total_spent(expenses)
    remaining = remaining(budget, spent)

    rows =
      expenses
      |> Enum.reverse()
      |> Enum.map(fn expense ->
        Map.merge(expense, %{
          amount_label: money(expense.amount),
          date_label: Calendar.strftime(expense.date, "%d %b")
        })
      end)

    category_rows =
      expenses
      |> categories()
      |> Enum.map(fn row ->
        row
        |> Map.put(:total_label, money(row.total))
        |> Map.put(:width, if(spent > 0, do: round(row.total / spent * 100), else: 0))
      end)

    assign(socket,
      spent: spent,
      remaining: remaining,
      spent_label: money(spent),
      budget_label: money(budget),
      remaining_label: money(remaining),
      budget_used: used_percent(budget, spent),
      meal_total: meal_total(expenses) |> money(),
      meal_count: Enum.count(expenses, &(&1.category == "Food")),
      meal_rows: Enum.filter(rows, &(&1.category == "Food")),
      expense_rows: rows,
      category_rows: category_rows,
      recent_expenses: Enum.take(rows, 6)
    )
  end

  defp load_user(session) do
    case session["user_id"] do
      nil ->
        nil

      identifier ->
        if String.match?(
             identifier,
             ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
           ) do
          Accounts.get_user(identifier)
        else
          Accounts.get_user_by_phone(identifier)
        end
    end
  end

  defp owns_ticket?(user, ticket) do
    phone = digits(user.phone)
    passenger = digits(ticket.passenger_phone || ticket.passenger_name)

    phone != "" and passenger != "" and
      (String.ends_with?(passenger, phone) or String.ends_with?(phone, passenger))
  end

  defp digits(value) do
    value
    |> to_string()
    |> String.replace(~r/\D/, "")
    |> String.trim_leading("254")
    |> String.trim_leading("0")
  end

  defp parse_amount(value) do
    case value |> to_string() |> String.replace(~r/[^\d.]/, "") |> Float.parse() do
      {number, ""} when number >= 0 -> {:ok, number}
      _other -> :error
    end
  end

  defp itinerary_meta(saved_itinerary) do
    start_date = saved_itinerary.start_date
    end_date = saved_itinerary.end_date

    date_label =
      cond do
        start_date && end_date ->
          "#{Calendar.strftime(start_date, "%a %d %b")} – #{Calendar.strftime(end_date, "%a %d %b %Y")}"

        start_date ->
          Calendar.strftime(start_date, "%a %d %b %Y")

        true ->
          "Dates to be confirmed"
      end

    subtitle =
      case saved_itinerary.country do
        country when is_binary(country) and country != "" ->
          "Chyllz AI itinerary · #{country}"

        _other ->
          "Chyllz AI itinerary"
      end

    %{
      title: saved_itinerary.title,
      subtitle: subtitle,
      date_label: date_label,
      days: Itineraries.duration_days(saved_itinerary),
      party: party_label(saved_itinerary.travel_party),
      status: status_label(Itineraries.status(saved_itinerary)),
      from: saved_itinerary.destination,
      to: saved_itinerary.country || "",
      reference: "AI-#{saved_itinerary.id}"
    }
  end

  defp party_label("solo"), do: "Only Me"
  defp party_label("couple"), do: "A Couple"
  defp party_label("family"), do: "Family"
  defp party_label("friends"), do: "Friends"
  defp party_label(_party), do: "Travellers"

  defp status_label(:upcoming), do: "Upcoming"
  defp status_label(:ongoing), do: "Ongoing"
  defp status_label(:completed), do: "Completed"

  defp persist_expense_edit(socket, id, attrs, keep_editing?) do
    amount = parse_amount(attrs["amount"] || "")
    label = String.trim(to_string(attrs["label"] || ""))
    category = if attrs["category"] in @expense_categories, do: attrs["category"], else: "Other"

    with {:ok, value} <- amount,
         false <- label == "",
         {:ok, _expense} <-
           TripFinances.update_expense(socket.assigns.finance_scope, id, %{
             label: label,
             category: category,
             amount: value
           }) do
      socket
      |> assign(:expenses, TripFinances.list_expenses(socket.assigns.finance_scope))
      |> assign(
        :editing_expense_id,
        if(keep_editing?, do: socket.assigns.editing_expense_id, else: nil)
      )
      |> assign_metrics()
    else
      _other -> socket
    end
  end

  defp amount_input(value) when is_number(value) and value == trunc(value) and value > 0 do
    Integer.to_string(trunc(value))
  end

  defp amount_input(value) when value == 0, do: ""

  defp amount_input(value) when is_number(value) and value > 0 do
    :erlang.float_to_binary(value * 1.0, decimals: 2)
  end

  defp amount_input(_value), do: ""

  defp expense_amount_input(value) when is_number(value) and value == trunc(value) do
    Integer.to_string(trunc(value))
  end

  defp expense_amount_input(value) when is_number(value) do
    :erlang.float_to_binary(value * 1.0, decimals: 2)
  end

  defp expense_amount_input(_value), do: ""

  defp trip_meta(ticket) do
    date = ticket.travel_date || Date.utc_today()

    %{
      title: "#{title_case(ticket.from)} → #{title_case(ticket.to)}",
      subtitle: ticket.company || "Komiuta bus trip",
      date_label:
        "#{Calendar.strftime(date, "%a %d %b %Y")}#{if ticket.departure, do: " · #{ticket.departure}", else: ""}",
      days: 1,
      party: "Only Me",
      status: trip_status(ticket),
      from: title_case(ticket.from),
      to: title_case(ticket.to),
      reference: ticket.ticket_id
    }
  end

  defp trip_status(ticket) do
    cond do
      ticket.status == "cancelled" ->
        "Cancelled"

      ticket.status == "pending" ->
        "Pending"

      ticket.travel_date && Date.compare(ticket.travel_date, Date.utc_today()) != :lt ->
        "Upcoming"

      true ->
        "Completed"
    end
  end

  defp title_case(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp total_spent(expenses), do: expenses |> Enum.map(& &1.amount) |> Enum.sum()
  defp remaining(budget, spent), do: max(budget - spent, 0)
  defp used_percent(budget, _spent) when budget == 0, do: 0

  defp used_percent(budget, spent) when is_number(budget) and is_number(spent) do
    min(round(spent / budget * 100), 100)
  end

  defp meal_total(expenses) do
    expenses
    |> Enum.filter(&(&1.category == "Food"))
    |> total_spent()
  end

  defp categories(expenses) do
    expenses
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {category, rows} -> %{category: category, total: total_spent(rows)} end)
    |> Enum.sort_by(& &1.total, :desc)
  end

  defp money(value) when is_integer(value), do: money(value * 1.0)

  defp money(value) do
    "KES " <>
      (value
       |> :erlang.float_to_binary(decimals: 0)
       |> add_thousands())
  end

  defp add_thousands(value) do
    value
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end
end
