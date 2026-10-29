defmodule XpressbusWeb.AdminCommsLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.AdminComponents
  alias Xpressbus.Accounts

  def mount(_params, session, socket) do
    admin_id = session["admin_id"]

    if admin_id do
      {:ok,
       socket
       |> assign(:page_title, "Comms Management")
       |> assign(:active_tab, "comms")
       |> assign(:sidebar_collapsed, false)
       |> assign(:bus_expanded, true)
       |> assign(:chyllz_expanded, true)
       |> assign(:settings_expanded, true)
       |> assign(:comms_tab, :whatsapp)
       |> assign(:selected_msg, nil)
       |> load_messages()}
    else
      {:ok,
       socket
       |> assign(:page_title, "Admin Login")
       |> Phoenix.LiveView.redirect(to: ~p"/admin/login")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-[#f8fafc]">
      <.sidebar
        active_tab={@active_tab}
        bus_expanded={@bus_expanded}
        chyllz_expanded={@chyllz_expanded}
        settings_expanded={@settings_expanded}
        collapsed={@sidebar_collapsed}
      />
      <div class={[
        "flex-1 transition-all duration-300 flex flex-col h-screen overflow-hidden",
        if(@sidebar_collapsed, do: "lg:pl-20", else: "lg:pl-72")
      ]}>
        <%!-- Fixed Header --%>
        <header class="h-20 bg-white border-b border-slate-100 flex items-center justify-between px-8 shrink-0">
          <h2 class="text-xl font-black text-slate-900 tracking-tight">Communications Inbox</h2>

          <div class="flex gap-3">
            <button class="bg-[#FF4C00] text-white px-6 py-2.5 rounded-xl font-black text-xs uppercase tracking-widest hover:bg-[#E64400] transition shadow-lg shadow-orange-200 flex items-center gap-2">
              <span class="material-symbols-outlined !text-base">add</span> New Campaign
            </button>
          </div>
        </header>
        <%!-- Inbox Controls --%>
        <div class="bg-white border-b border-slate-50 px-8 py-3 shrink-0 flex items-center justify-between">
          <div class="flex items-center gap-2 overflow-x-auto no-scrollbar">
            <.comms_tab_btn id={:whatsapp} icon="chat" label="WhatsApp" active={@comms_tab} />
            <.comms_tab_btn id={:sms} icon="sms" label="SMS" active={@comms_tab} />
            <.comms_tab_btn id={:email} icon="mail" label="Email" active={@comms_tab} />
            <.comms_tab_btn id={:newsletter} icon="campaign" label="Newsletter" active={@comms_tab} />
            <.comms_tab_btn
              id={:subscribe}
              icon="notifications_active"
              label="Subscribe"
              active={@comms_tab}
            />
          </div>

          <div class="hidden md:flex items-center gap-4">
            <div class="relative">
              <span class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 !text-base">search</span>
              <input
                type="text"
                placeholder="Search threads..."
                class="bg-slate-50 border border-slate-100 rounded-full pl-9 pr-4 py-2 text-xs font-bold focus:bg-white focus:border-orange-500 outline-none transition w-64"
              />
            </div>
          </div>
        </div>
        <%!-- Main Inbox Layout --%>
        <main class="flex-1 flex overflow-hidden">
          <%!-- Message List --%>
          <div class="w-full md:w-[400px] bg-white border-r border-slate-100 flex flex-col overflow-y-auto no-scrollbar">
            <%= for msg <- @messages do %>
              <div
                phx-click="select_msg"
                phx-value-id={msg.id}
                class={[
                  "p-5 border-b border-slate-50 cursor-pointer transition-all hover:bg-slate-50 relative",
                  @selected_msg && @selected_msg.id == msg.id && "bg-[#FF4C00]/10"
                ]}
              >
                <%= if @selected_msg && @selected_msg.id == msg.id do %>
                  <div class="absolute left-0 top-0 bottom-0 w-1 bg-[#FF4C00]"></div>
                <% end %>

                <div class="flex justify-between items-start mb-1">
                  <span class="text-sm font-black text-slate-900 tracking-tight truncate mr-2">{msg.sender}</span>
                  <span class="text-[10px] font-black text-slate-400 whitespace-nowrap">{msg.time}</span>
                </div>

                <div class="text-[11px] font-black text-[#FF4C00] uppercase tracking-wider mb-2">
                  {msg.subject}
                </div>

                <p class="text-xs font-bold text-slate-500 line-clamp-2 leading-relaxed">
                  {msg.snippet}
                </p>

                <div class="mt-3 flex items-center justify-between">
                  <span class={[
                    "text-[9px] font-black px-2 py-0.5 rounded-md uppercase",
                    msg.status == "Sent" && "bg-green-50 text-green-600",
                    msg.status == "Pending" && "bg-yellow-50 text-yellow-600",
                    msg.status == "Draft" && "bg-slate-100 text-slate-500"
                  ]}>
                    {msg.status}
                  </span>

                  <div class="flex -space-x-1">
                    <div class="w-5 h-5 rounded-full bg-slate-200 border border-white"></div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
          <%!-- Message Preview --%>
          <div class="hidden md:flex flex-1 bg-slate-50/50 flex-col overflow-y-auto p-12">
            <%= if @selected_msg do %>
              <div class="max-w-3xl mx-auto w-full">
                <div class="bg-white rounded-[2.5rem] p-10 shadow-sm border border-slate-100">
                  <div class="flex justify-between items-start mb-10">
                    <div class="flex items-center gap-5">
                      <div class="w-14 h-14 bg-slate-900 rounded-2xl flex items-center justify-center text-white text-xl font-black">
                        {String.at(@selected_msg.sender, 0)}
                      </div>

                      <div>
                        <h3 class="text-xl font-black text-slate-900 tracking-tight">
                          {@selected_msg.sender}
                        </h3>

                        <p class="text-sm font-bold text-slate-400">{@selected_msg.contact}</p>
                      </div>
                    </div>

                    <div class="flex gap-2">
                      <button class="w-10 h-10 rounded-full bg-slate-50 flex items-center justify-center text-slate-400 hover:text-[#FF4C00] transition-colors">
                        <span class="material-symbols-outlined !text-xl">reply</span>
                      </button>

                      <button class="w-10 h-10 rounded-full bg-slate-50 flex items-center justify-center text-slate-400 hover:text-red-500 transition-colors">
                        <span class="material-symbols-outlined !text-xl">delete</span>
                      </button>
                    </div>
                  </div>

                  <div class="mb-8">
                    <div class="text-[10px] font-black text-[#FF4C00] uppercase tracking-widest mb-2">
                      Message Content
                    </div>

                    <h4 class="text-2xl font-black text-slate-900 tracking-tighter leading-tight mb-6">
                      {@selected_msg.subject}
                    </h4>

                    <div class="prose prose-slate max-w-none text-slate-600 font-bold leading-relaxed whitespace-pre-wrap">
                      {@selected_msg.body}
                    </div>
                  </div>

                  <div class="pt-8 border-t border-slate-50 flex items-center justify-between">
                    <div class="flex items-center gap-3">
                      <span class="material-symbols-outlined text-slate-300">calendar_month</span>
                      <span class="text-xs font-bold text-slate-400">Sent on Aug 24, 2026 at 10:45 AM</span>
                    </div>

                    <div class="flex items-center gap-2">
                      <span class="w-2 h-2 bg-green-500 rounded-full"></span>
                      <span class="text-[10px] font-black uppercase text-slate-400">Delivered</span>
                    </div>
                  </div>
                </div>
              </div>
            <% else %>
              <div class="flex-1 flex flex-col items-center justify-center text-center">
                <div class="w-20 h-20 bg-white rounded-3xl shadow-sm border border-slate-100 flex items-center justify-center text-slate-200 mb-6">
                  <span class="material-symbols-outlined !text-4xl">inbox</span>
                </div>

                <h3 class="text-xl font-black text-slate-400 tracking-tight">
                  Select a conversation to read
                </h3>

                <p class="text-sm font-bold text-slate-300 max-w-xs mx-auto mt-2">
                  Manage all your cross-channel communications from this industrial dashboard.
                </p>
              </div>
            <% end %>
          </div>
        </main>
      </div>
    </div>
    """
  end

  defp comms_tab_btn(assigns) do
    ~H"""
    <button
      phx-click="change_comms_tab"
      phx-value-tab={@id}
      class={[
        "flex items-center gap-2 px-5 py-2.5 rounded-xl text-xs font-black uppercase tracking-widest transition-all shrink-0",
        @active == @id && "bg-[#FF4C00] text-white shadow-lg shadow-orange-100",
        @active != @id && "text-slate-400 hover:bg-slate-50 hover:text-slate-900"
      ]}
    >
      <span class="material-symbols-outlined !text-base">{@icon}</span> {@label}
    </button>
    """
  end

  def handle_event("change_comms_tab", %{"tab" => tab}, socket) do
    tab = String.to_existing_atom(tab)

    {:noreply,
     socket
     |> assign(:comms_tab, tab)
     |> assign(:selected_msg, nil)
     |> load_messages()}
  end

  def handle_event("select_msg", %{"id" => id}, socket) do
    msg = Enum.find(socket.assigns.messages, &(&1.id == id))
    {:noreply, assign(socket, :selected_msg, msg)}
  end

  def handle_event("toggle_bus", %{"category" => "bus"}, socket) do
    bus_expanded = not socket.assigns.bus_expanded
    {:noreply, assign(socket, :bus_expanded, bus_expanded)}
  end

  def handle_event("toggle_chyllz", %{"category" => "chyllz"}, socket) do
    chyllz_expanded = not socket.assigns.chyllz_expanded
    {:noreply, assign(socket, :chyllz_expanded, chyllz_expanded)}
  end

  def handle_event("toggle_settings", %{"category" => "settings"}, socket) do
    settings_expanded = not socket.assigns.settings_expanded
    {:noreply, assign(socket, :settings_expanded, settings_expanded)}
  end

  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :sidebar_collapsed, not socket.assigns.sidebar_collapsed)}
  end

  defp load_messages(socket) do
    messages =
      case socket.assigns.comms_tab do
        :whatsapp ->
          [
            %{
              id: "w1",
              sender: "John Doe",
              contact: "+254 712 345 678",
              subject: "Inquiry",
              snippet: "Hi, is the 8PM bus to Mombasa on schedule? I am running a bit late.",
              time: "10:45 AM",
              status: "Pending",
              body:
                "Hi Komiuta Support,\n\nI have a booking for the 8:00 PM bus from Nairobi to Mombasa (Ticket #KMT-901). I'm currently stuck in traffic near Westlands.\n\nIs the bus on schedule? And how long will it wait at the terminal?\n\nBest regards,\nJohn"
            },
            %{
              id: "w2",
              sender: "Jane Smith",
              contact: "+254 788 888 888",
              subject: "Seat Change",
              snippet: "Can I change my seat from 12 to 5? I prefer the window view.",
              time: "09:30 AM",
              status: "Sent",
              body:
                "Hello,\n\nI'd like to request a seat change for my trip tomorrow morning. I'm currently in seat 12 but I saw seat 5 is available. Can you swap them for me?\n\nThanks!"
            }
          ]

        :sms ->
          [
            %{
              id: "s1",
              sender: "Komiuta System",
              contact: "To: +254 700 111 222",
              subject: "Booking Confirm",
              snippet:
                "Your booking KMT-992 is confirmed. Departure: 08:00 PM, Nairobi Terminal.",
              time: "Yesterday",
              status: "Sent",
              body:
                "Komiuta: Your booking KMT-992 is confirmed. Departure: 08:00 PM today from Nairobi Main Terminal. Please arrive 30 mins early. Ref: https://kmt.io/tkt/992"
            },
            %{
              id: "s2",
              sender: "Komiuta System",
              contact: "To: +254 722 333 444",
              subject: "Delay Alert",
              snippet: "URGENT: Bus MashPoa KCH 442Y is delayed by 30 mins due to logistics.",
              time: "Aug 23",
              status: "Sent",
              body:
                "Komiuta Alert: Bus MashPoa KCH 442Y is delayed by 30 mins. New departure time is 08:30 PM. We apologize for the inconvenience."
            }
          ]

        :email ->
          [
            %{
              id: "e1",
              sender: "Komiuta Brand",
              contact: "marketing@komiuta.com",
              subject: "Welcome aboard!",
              snippet:
                "Welcome to Komiuta. Elevate your journey with us. Here is a gift for you...",
              time: "2 days ago",
              status: "Sent",
              body:
                "Hello Traveler,\n\nWelcome to Komiuta! We are thrilled to have you join our community of over 830,000 explorers.\n\nAs a welcome gift, use the code GOLD10 for 10% off your next booking.\n\nSafe travels!"
            },
            %{
              id: "e2",
              sender: "Booking System",
              contact: "tickets@komiuta.com",
              subject: "Your E-Ticket",
              snippet:
                "Thank you for booking with Komiuta. Attached is your E-Ticket for NBO -> MSA.",
              time: "Aug 20",
              status: "Sent",
              body:
                "Dear Customer,\n\nThank you for choosing Komiuta. Your payment of KSH 1,500 has been received.\n\nTrip: Nairobi to Mombasa\nDate: Sept 03, 2026\nSeat: 4 (VIP)\n\nPlease present the attached PDF at the boarding point."
            }
          ]

        :newsletter ->
          [
            %{
              id: "n1",
              sender: "Komiuta Dispatch",
              contact: "12,400 Subscribers",
              subject: "Weekly Insights #42",
              snippet: "Discover the hidden gems of Kwale and the best budget stays in Lamu...",
              time: "Aug 15",
              status: "Sent",
              body:
                "THE KOMIUTA DISPATCH\nIssue #42: Coastal Wonders\n\nIn this week's issue:\n1. Chale Island: East Africa's best kept secret.\n2. 5 Budget Boutique Hotels in Lamu.\n3. New intercity EV routes starting next month.\n\nRead more on our blog!"
            },
            %{
              id: "n2",
              sender: "Marketing Team",
              contact: "15,000 Subscribers",
              subject: "Easter Specials",
              snippet:
                "Get ready for the Easter break with exclusive deals on car hire and resorts.",
              time: "Draft",
              status: "Draft",
              body:
                "COMING SOON: Easter 2027 Specials.\n\nDrafting content for early bird discounts on luxury car hire and beachfront resort stays in Watamu and Malindi."
            }
          ]

        :subscribe ->
          Accounts.list_subscribers()
          |> Enum.map(fn sub ->
            %{
              id: to_string(sub.id),
              sender: sub.email,
              contact: sub.source,
              subject: "New Subscription",
              snippet: "Newsletter signup from #{sub.source}.",
              time: Calendar.strftime(sub.inserted_at, "%b %d"),
              status: sub.status,
              body:
                "Newsletter Subscription Details\n\nEmail: #{sub.email}\nSource: #{sub.source}\nStatus: #{sub.status}\nJoined on: #{Calendar.strftime(sub.inserted_at, "%B %d, %Y at %I:%M %p")}"
            }
          end)
      end

    assign(socket, :messages, messages)
  end
end
