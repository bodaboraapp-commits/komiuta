defmodule XpressbusWeb.AdminComponents do
  use XpressbusWeb, :html

  attr :active_tab, :string, default: "dashboard"
  attr :bus_expanded, :boolean, default: true
  attr :chyllz_expanded, :boolean, default: true
  attr :settings_expanded, :boolean, default: true
  attr :collapsed, :boolean, default: false

  def sidebar(assigns) do
    ~H"""
    <aside class={[
      "min-h-screen bg-white border-r border-slate-100 flex flex-col shrink-0 overflow-y-auto no-scrollbar fixed left-0 top-0 z-40 transition-all duration-300 ease-in-out",
      if(@collapsed, do: "w-20", else: "w-72")
    ]}>
      <%!-- Logo Section --%>
      <div class="p-4 flex items-center justify-between">
        <div class="relative group/logo">
          <div class="flex items-center gap-2 overflow-hidden">
            <div class="w-8 h-8 bg-[#FF4C00] rounded-xl flex items-center justify-center text-white overflow-hidden shadow-lg shadow-orange-100 relative shrink-0">
              <div class="absolute inset-0 bg-gradient-to-br from-[#FF4C00] to-[#FF8C00]"></div>
              <span class="material-symbols-outlined !text-2xl relative z-10">directions_bus</span>
            </div>
            <span
              :if={!@collapsed}
              class="text-lg font-black tracking-tighter text-slate-900 whitespace-nowrap"
            >Komiuta</span>
          </div>
          <%= if @collapsed do %>
            <div class="absolute left-full ml-4 top-1/2 -translate-y-1/2 px-3 py-1.5 bg-slate-900 text-white text-xs font-black rounded-lg opacity-0 pointer-events-none group-hover/logo:opacity-100 transition-opacity z-50 whitespace-nowrap shadow-xl">
              Komiuta
              <div class="absolute right-full top-1/2 -translate-y-1/2 border-8 border-transparent border-r-slate-900">
              </div>
            </div>
          <% end %>
        </div>

        <div class="relative group/menu">
          <button
            phx-click="toggle_sidebar"
            class={[
              "flex items-center justify-center text-white shadow-md shadow-orange-200 hover:bg-[#E64400] transition-colors shrink-0",
              @collapsed && "w-5 h-5 rounded !text-base",
              !@collapsed && "w-8 h-8 bg-[#FF4C00] rounded-lg !text-xl"
            ]}
          >
            <span class="material-symbols-outlined">{if @collapsed, do: "chevron_right", else: "menu"}</span>
          </button>
          <%= if @collapsed do %>
            <div class="absolute left-full ml-4 top-1/2 -translate-y-1/2 px-3 py-1.5 bg-slate-900 text-white text-xs font-black rounded-lg opacity-0 pointer-events-none group-hover/menu:opacity-100 transition-opacity z-50 whitespace-nowrap shadow-xl">
              Expand Menu
              <div class="absolute right-full top-1/2 -translate-y-1/2 border-8 border-transparent border-r-slate-900">
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Shared Items --%>
      <div class="px-3 pt-2">
        <.nav_item
          icon="home"
          label="Dashboard"
          id="dashboard"
          href="/admin/dashboard"
          active={@active_tab}
          collapsed={@collapsed}
        />
        <.nav_item
          icon="analytics"
          label="Analytics"
          id="analytics"
          active={@active_tab}
          collapsed={@collapsed}
        />
        <.nav_item
          icon="description"
          label="Reports"
          id="reports"
          active={@active_tab}
          collapsed={@collapsed}
        />
      </div>
      <%!-- Bus Category --%>
      <div
        class="px-3 pt-4 group/cat"
        phx-click={!@collapsed && "toggle_bus"}
        phx-value-category="bus"
      >
        <div class="flex items-center gap-3 pt-[3px]">
          <span :if={@collapsed} class="material-symbols-outlined text-slate-300 text-base mx-auto">more_horiz</span>
          <p :if={!@collapsed} class="text-xs font-black tracking-widest text-slate-500 uppercase">
            Bus
          </p>

          <span
            :if={!@collapsed}
            class="w-6 h-6 rounded-full bg-white flex items-center justify-center text-slate-600 text-lg font-black transition-transform duration-200 ml-auto"
          >
            <%= if @bus_expanded do %>
              −
            <% else %>
              +
            <% end %>
          </span>
        </div>

        <div class={[
          "mt-2",
          (@bus_expanded || @collapsed) && "block",
          !@bus_expanded && !@collapsed && "hidden"
        ]}>
          <.nav_item
            icon="location_on"
            label="City"
            id="city"
            href="/admin/city"
            active={@active_tab}
            has_arrow={!@collapsed}
            collapsed={@collapsed}
          />
          <.nav_item
            icon="image"
            label="Banner"
            id="banner"
            href="/admin/banners"
            active={@active_tab}
            has_arrow={!@collapsed}
            collapsed={@collapsed}
          />
          <.nav_item
            icon="route"
            label="Routes"
            id="routes"
            href="/admin/routes"
            active={@active_tab}
            has_arrow={!@collapsed}
            collapsed={@collapsed}
          />
          <.nav_item
            icon="directions_bus"
            label="Fleet (Add Bus)"
            id="fleet"
            href="/admin/buses"
            active={@active_tab}
            has_arrow={!@collapsed}
            collapsed={@collapsed}
          />
          <.nav_item
            icon="pin_drop"
            label="Drop/Pick Point"
            id="points"
            href="/admin/drop-pick-points"
            active={@active_tab}
            has_arrow={!@collapsed}
            collapsed={@collapsed}
          />
          <.nav_item
            icon="directions_bus"
            label="Bus Operator"
            id="operators"
            href="/admin/bus-operators"
            active={@active_tab}
            has_arrow={!@collapsed}
            collapsed={@collapsed}
          />
          <.nav_item
            icon="headset_mic"
            label="Facility"
            id="facility"
            href="/admin/facilities"
            active={@active_tab}
            has_arrow={!@collapsed}
            collapsed={@collapsed}
          />
        </div>
      </div>
      <%!-- Chyllz Category --%>
      <div class="px-3 pt-4" phx-click={!@collapsed && "toggle_chyllz"} phx-value-category="chyllz">
        <div class="flex items-center gap-3 pt-[3px]">
          <span :if={@collapsed} class="material-symbols-outlined text-slate-300 text-base mx-auto">more_horiz</span>
          <p :if={!@collapsed} class="text-xs font-black tracking-widest text-slate-500 uppercase">
            Chyllz
          </p>

          <span
            :if={!@collapsed}
            class="w-6 h-6 rounded-full bg-white flex items-center justify-center text-slate-600 text-lg font-black transition-transform duration-200 ml-auto"
          >
            <%= if @chyllz_expanded do %>
              −
            <% else %>
              +
            <% end %>
          </span>
        </div>

        <div class={[
          "mt-2",
          (@chyllz_expanded || @collapsed) && "block",
          !@chyllz_expanded && !@collapsed && "hidden"
        ]}>
          <.nav_item
            icon="local_hotel"
            label="Hotels"
            id="hotels"
            active={@active_tab}
            has_arrow={!@collapsed}
            href="/admin/hotels"
            collapsed={@collapsed}
          />
          <.nav_item
            icon="explore"
            label="Hidden Gems"
            id="hidden-gems"
            active={@active_tab}
            has_arrow={!@collapsed}
            href="/admin/hidden-gems"
            collapsed={@collapsed}
          />
          <.nav_item
            icon="directions_car"
            label="Cars"
            id="cars"
            active={@active_tab}
            has_arrow={!@collapsed}
            href="/admin/car-hires"
            collapsed={@collapsed}
          />
          <.nav_item
            icon="event"
            label="Events"
            id="events"
            active={@active_tab}
            has_arrow={!@collapsed}
            href="/admin/events"
            collapsed={@collapsed}
          />
        </div>
      </div>
      <%!-- Settings Category --%>
      <div
        class="px-3 pt-4"
        phx-click={!@collapsed && "toggle_settings"}
        phx-value-category="settings"
      >
        <div class="flex items-center gap-3 pt-[3px]">
          <span :if={@collapsed} class="material-symbols-outlined text-slate-300 text-base mx-auto">more_horiz</span>
          <p :if={!@collapsed} class="text-xs font-black tracking-widest text-slate-500 uppercase">
            Settings
          </p>

          <span
            :if={!@collapsed}
            class="w-6 h-6 rounded-full bg-white flex items-center justify-center text-slate-600 text-lg font-black transition-transform duration-200 ml-auto"
          >
            <%= if @settings_expanded do %>
              −
            <% else %>
              +
            <% end %>
          </span>
        </div>

        <div class={[
          "mt-2",
          (@settings_expanded || @collapsed) && "block",
          !@settings_expanded && !@collapsed && "hidden"
        ]}>
          <.nav_item
            icon="forum"
            label="FAQ"
            id="faq"
            active={@active_tab}
            has_arrow={!@collapsed}
            collapsed={@collapsed}
          />
          <.nav_item
            icon="chat"
            label="Comms"
            id="comms"
            active={@active_tab}
            href="/admin/comms"
            has_arrow={!@collapsed}
            collapsed={@collapsed}
          />
          <.nav_item
            icon="policy"
            label="Cancel Policy"
            id="policy"
            active={@active_tab}
            has_arrow={!@collapsed}
            collapsed={@collapsed}
          />
          <.nav_item
            icon="payments"
            label="Payment List"
            id="payments"
            active={@active_tab}
            has_arrow={!@collapsed}
            collapsed={@collapsed}
          />
          <.nav_item
            icon="account_balance_wallet"
            label="Integrations"
            id="mpesa"
            active={@active_tab}
            href="/admin/integration"
            has_arrow={!@collapsed}
            collapsed={@collapsed}
          />
          <.nav_item
            icon="redeem"
            label="Coupons"
            id="coupons"
            active={@active_tab}
            href="/admin/coupons"
            has_arrow={!@collapsed}
            collapsed={@collapsed}
          />
          <.nav_item
            icon="route"
            label="Trip Report"
            id="trips"
            active={@active_tab}
            has_arrow={!@collapsed}
            collapsed={@collapsed}
          />
          <.nav_item
            icon="account_balance_wallet"
            label="Agent Payout"
            id="payouts"
            active={@active_tab}
            has_arrow={!@collapsed}
            collapsed={@collapsed}
          />
          <.nav_item
            icon="library_books"
            label="Page"
            id="pages"
            active={@active_tab}
            has_arrow={!@collapsed}
            collapsed={@collapsed}
          />
          <.nav_item
            icon="group"
            label="User/Agent List"
            id="users"
            active={@active_tab}
            has_arrow={!@collapsed}
            collapsed={@collapsed}
          />
        </div>
      </div>
      <%!-- Logout --%>
      <div class="mt-auto p-4 border-t border-slate-50">
        <a
          href="/admin/logout"
          class="flex items-center gap-2 text-slate-400 font-bold hover:text-red-500 transition-colors justify-center md:justify-start"
        >
          <span class="material-symbols-outlined">logout</span>
          <span :if={!@collapsed} class="text-xs">Logout</span>
        </a>
      </div>
    </aside>
    """
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :id, :string, required: true
  attr :active, :string, required: true
  attr :href, :string, default: nil
  attr :has_arrow, :boolean, default: false
  attr :collapsed, :boolean, default: false

  def nav_item(assigns) do
    ~H"""
    <div class="relative group/nav">
      <% is_active = @id == @active %>
      <%= if @href do %>
        <.link
          navigate={@href}
          class={[
            "flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-bold transition-all mb-1",
            is_active && "bg-[#FF4C00]/10 text-[#FF4C00]",
            !is_active && "text-slate-500 hover:bg-slate-50 hover:text-slate-900",
            @collapsed && "justify-center px-0"
          ]}
        >
          <span class={["material-symbols-outlined text-base shrink-0", @collapsed && "!text-xl"]}>{@icon}</span>
          <span :if={!@collapsed} class="truncate">{@label}</span>
          <%= if @has_arrow and !@collapsed do %>
            <span class="w-6 h-6 rounded-full bg-white flex items-center justify-center ml-auto shadow-sm shrink-0">
              <span class="material-symbols-outlined !text-[14px] text-slate-400 !leading-none">chevron_right</span>
            </span>
          <% end %>
        </.link>
      <% else %>
        <div class={[
          "flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-bold transition-all mb-1",
          is_active && "bg-[#FF4C00]/10 text-[#FF4C00]",
          !is_active && "text-slate-500 hover:bg-slate-50 hover:text-slate-900",
          @collapsed && "justify-center px-0"
        ]}>
          <span class={["material-symbols-outlined text-base shrink-0", @collapsed && "!text-xl"]}>{@icon}</span>
          <span :if={!@collapsed} class="truncate">{@label}</span>
          <%= if @has_arrow and !@collapsed do %>
            <span class="w-6 h-6 rounded-full bg-white flex items-center justify-center ml-auto shadow-sm shrink-0">
              <span class="material-symbols-outlined !text-[14px] text-slate-400 !leading-none">chevron_right</span>
            </span>
          <% end %>
        </div>
      <% end %>
      <%!-- Tooltip for Collapsed State --%>
      <%= if @collapsed do %>
        <div class="absolute left-full ml-4 top-1/2 -translate-y-1/2 px-3 py-1.5 bg-slate-900 text-white text-xs font-black rounded-lg opacity-0 pointer-events-none group-hover/nav:opacity-100 transition-opacity z-50 whitespace-nowrap shadow-xl">
          {@label}
          <div class="absolute right-full top-1/2 -translate-y-1/2 border-8 border-transparent border-r-slate-900">
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  attr :page, :integer, required: true
  attr :page_size, :integer, required: true
  attr :total_count, :integer, required: true

  def pager(assigns) do
    total_pages = ceil(assigns.total_count / assigns.page_size)
    total_pages = if total_pages < 1, do: 1, else: total_pages
    assigns = assign(assigns, :total_pages, total_pages)

    ~H"""
    <div class="p-8 bg-slate-50/30 border-t border-slate-50 flex flex-col md:flex-row justify-between items-center gap-6">
      <p class="text-sm font-bold text-slate-400">
        Showing {if @total_count > 0, do: (@page - 1) * @page_size + 1, else: 0} to {min(
          @page * @page_size,
          @total_count
        )} of {@total_count} entries
      </p>

      <div class="flex items-center gap-2">
        <button
          phx-click={if @page > 1, do: "change_page"}
          phx-value-page={@page - 1}
          disabled={@page <= 1}
          class={[
            "px-4 py-2 text-sm font-black transition-all",
            if(@page <= 1,
              do: "text-slate-200 cursor-not-allowed",
              else: "text-slate-500 hover:text-[#FF4C00]"
            )
          ]}
        >
          Previous
        </button>

        <%= for p <- 1..@total_pages do %>
          <%= if p == @page do %>
            <button class="w-10 h-10 bg-[#FF4C00] rounded-xl flex items-center justify-center text-white font-black shadow-lg shadow-orange-100">
              {p}
            </button>
          <% else %>
            <button
              phx-click="change_page"
              phx-value-page={p}
              class="w-10 h-10 bg-white border border-slate-100 rounded-xl flex items-center justify-center text-slate-500 font-black hover:bg-slate-50 transition-all"
            >
              {p}
            </button>
          <% end %>
        <% end %>

        <button
          phx-click={if @page < @total_pages, do: "change_page"}
          phx-value-page={@page + 1}
          disabled={@page >= @total_pages}
          class={[
            "px-4 py-2 text-sm font-black transition-all",
            if(@page >= @total_pages,
              do: "text-slate-200 cursor-not-allowed",
              else: "text-slate-500 hover:text-[#FF4C00]"
            )
          ]}
        >
          Next
        </button>
      </div>
    </div>
    """
  end
end
