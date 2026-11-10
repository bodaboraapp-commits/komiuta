defmodule XpressbusWeb.TripManageLive do
  use XpressbusWeb, :live_view

  alias Xpressbus.{Accounts, Tickets}

  @tabs [
    {"expenses", "Expenses", "payments"},
    {"meals", "Meals & Food", "restaurant"},
    {"summary", "Summary", "category"},
    {"places", "Visited Places", "history"}
  ]

  @expense_categories ["Food", "Transport", "Stay", "Activities", "Shopping", "Other"]

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
              socket =
                socket
                |> assign(:page_title, "Manage itinerary — #{ticket.from} → #{ticket.to}")
                |> assign(:page_robots, "noindex,nofollow")
                |> assign(:current_user, user.phone)
                |> assign(:user, user)
                |> assign(:ticket, ticket)
                |> assign(:tabs, @tabs)
                |> assign(:active_tab, "expenses")
                |> assign(:categories, @expense_categories)
                |> assign(:expenses, [])
                |> assign(:budget, 0)
                |> assign(:budget_form, false)
                |> assign(:expense_form, false)
                |> assign(:expense_category, "Food")
                |> assign(:error, nil)
                |> assign(:trip, trip_meta(ticket))
                |> assign_metrics()

              {:ok, socket}
            else
              {:ok, redirect(socket, to: "/dashboard")}
            end
        end
    end
  end

  def handle_event("set_tab", %{"tab" => tab}, socket) do
    if tab in Enum.map(@tabs, &elem(&1, 0)) do
      {:noreply, assign(socket, :active_tab, tab)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_budget", _params, socket) do
    {:noreply, assign(socket, :budget_form, not socket.assigns.budget_form)}
  end

  def handle_event("toggle_expense", _params, socket) do
    {:noreply, assign(socket, :expense_form, not socket.assigns.expense_form)}
  end

  def handle_event("save_budget", %{"budget" => %{"amount" => amount}}, socket) do
    case parse_amount(amount) do
      {:ok, value} ->
        socket
        |> assign(:budget, value)
        |> assign(:budget_form, false)
        |> assign(:error, nil)
        |> assign_metrics()
        |> then(&{:noreply, &1})

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

        expense = %{
          id: System.unique_integer([:positive]),
          label: label,
          category: category,
          amount: value,
          date: Date.utc_today()
        }

        {:noreply,
         socket
         |> assign(:expenses, socket.assigns.expenses ++ [expense])
         |> assign(:expense_form, false)
         |> assign(:error, nil)
         |> assign_metrics()}
    end
  end

  def handle_event("delete_expense", %{"id" => id}, socket) do
    expenses = Enum.reject(socket.assigns.expenses, &(Integer.to_string(&1.id) == id))
    {:noreply, socket |> assign(:expenses, expenses) |> assign_metrics()}
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
  defp used_percent(0, _spent), do: 0
  defp used_percent(budget, spent), do: min(round(spent / budget * 100), 100)

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
