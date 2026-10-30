defmodule XpressbusWeb.BrandComponents do
  use XpressbusWeb, :html

  attr :step, :atom, default: :search
  attr :footer_tab, :string, default: "about"
  attr :live_stats, :map, default: nil
  attr :current_user, :string, default: nil

  def main_header(assigns) do
    ~H"""
    <header class="fixed top-0 left-0 right-0 z-50 bg-white/95 backdrop-blur-md border-b border-orange-500/50 shadow-sm transition-all duration-300 font-sans font-bold">
      <div class="max-w-[1350px] mx-auto px-4 xl:px-6 py-4 flex items-center justify-between gap-4">
        <div class="flex items-center gap-6 xl:gap-12">
          <a href="/" class="flex-shrink-0">
            <img
              src="/images/logo_brand.png"
              alt="Komiuta"
              width="190"
              height="52"
              class="h-10 md:h-12 w-auto object-contain"
            />
          </a>

          <nav class="hidden lg:flex items-center gap-4 xl:gap-8 whitespace-nowrap">
            <a href="/" class="flex flex-col items-center gap-1 group relative">
              <span class={[
                "material-symbols-outlined transition-colors !text-2xl",
                if(@step in [:search, :results, :passenger_info, :review_and_pay],
                  do: "text-[#FF4C00]",
                  else: "text-slate-400 group-hover:text-[#FF4C00]"
                )
              ]}>directions_bus</span>
              <span class={[
                "text-[11px] font-black uppercase tracking-widest",
                if(@step in [:search, :results, :passenger_info, :review_and_pay],
                  do: "text-slate-900",
                  else: "text-slate-400 group-hover:text-slate-900"
                )
              ]}>Bus Tickets</span>
              <%= if @step in [:search, :results, :passenger_info, :review_and_pay] do %>
                <div class="absolute -bottom-[22px] left-0 right-0 h-1 bg-[#FF4C00] rounded-t-full">
                </div>
              <% end %>
            </a>

            <a href="/tour-packages" class="flex flex-col items-center gap-1 group relative">
              <div class={[
                "w-7 h-7 flex items-center justify-center transition-colors",
                if(@step in [:chyllz, :hotels, :gems, :car, :events],
                  do: "text-[#FF4C00]",
                  else: "text-slate-400 group-hover:text-[#FF4C00]"
                )
              ]}>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  width="28"
                  height="28"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.8"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  class="w-7 h-7"
                >
                  <path d="M2 11h20v1c0 5-4.48 9-10 9s-10-4-10-9v-1z" />
                  <path d="M2.5 14h19" opacity="0.3" /> <path d="M12 21v2" /> <path d="M8 23h8" />
                  <circle cx="6" cy="11" r="3.5" /> <path d="M6 7.5v7" /> <path d="M17 11l2-7" />
                  <path d="M19 4l-5 3.5 5 1.5 5-1.5z" /> <path d="M19 4l5 3.5-5 1.5-5-1.5z" />
                  <path d="M19 4v5M16.5 5.5l5 3M14 7h10" opacity="0.6" />
                </svg>
              </div>

              <span class={[
                "text-[11px] font-black uppercase tracking-widest",
                if(@step in [:chyllz, :hotels, :gems, :car, :events],
                  do: "text-slate-900",
                  else: "text-slate-400 group-hover:text-slate-900"
                )
              ]}>Chyllz</span>
              <%= if @step in [:chyllz, :hotels, :gems, :car, :events] do %>
                <div class="absolute -bottom-[22px] left-0 right-0 h-1 bg-[#FF4C00] rounded-t-full">
                </div>
              <% end %>
            </a>

            <a href="/tour-packages/insurance" class="flex flex-col items-center gap-1 group relative">
              <span class={[
                "material-symbols-outlined transition-colors !text-2xl",
                if(@step == :insurance,
                  do: "text-[#FF4C00]",
                  else: "text-slate-400 group-hover:text-[#FF4C00]"
                )
              ]}>shield</span>

              <span class={[
                "text-[11px] font-black uppercase tracking-widest",
                if(@step == :insurance,
                  do: "text-slate-900",
                  else: "text-slate-400 group-hover:text-slate-900"
                )
              ]}>InSURE</span>
              <%= if @step == :insurance do %>
                <div class="absolute -bottom-[22px] left-0 right-0 h-1 bg-[#FF4C00] rounded-t-full">
                </div>
              <% end %>
            </a>
          </nav>
        </div>

        <div class="hidden lg:flex items-center gap-2.5 xl:gap-6 whitespace-nowrap">
          <a
            href="/partner/add-fleet"
            target="_blank"
            rel="noopener noreferrer"
            class="flex items-center gap-2 text-sm font-bold text-slate-600 hover:text-[#FF4C00] transition"
          >
            <span class="material-symbols-outlined" aria-hidden="true">directions_bus</span> Add Bus
          </a>

          <a
            id="pwa-download-desktop"
            href="#app-section"
            phx-hook=".InstallApp"
            class="pwa-hide-installed flex items-center gap-2 text-sm font-bold text-slate-600 hover:text-[#FF4C00] transition"
          >
            <span class="material-symbols-outlined" aria-hidden="true">download</span> Download App
          </a>

          <a
            id="header-track-ticket"
            href="/tickets"
            title="Track your ticket"
            aria-label="Track your ticket"
            aria-current={if(@step == :ticket, do: "page", else: nil)}
            class={[
              "hidden lg:flex items-center gap-2 text-sm font-black px-3 xl:px-5 py-2.5 rounded-full border transition-all shadow-sm",
              if(@step == :ticket,
                do: "bg-[#FF4C00] text-white border-[#FF4C00] shadow-orange-200",
                else:
                  "bg-white text-[#FF4C00] border-orange-100 hover:bg-[#FF4C00] hover:text-white hover:border-[#FF4C00] hover:shadow-orange-200"
              )
            ]}
          >
            <span class="material-symbols-outlined !text-lg" aria-hidden="true">confirmation_number</span>
            <span class="track-pill-label">Track Ticket</span>
          </a>

          <%= if @current_user do %>
            <a
              href="/dashboard"
              class="flex items-center gap-2 text-sm font-bold text-white bg-[#FF4C00] px-6 py-2.5 rounded-full hover:bg-[#E64400] transition shadow-lg shadow-orange-200"
            >
              <span class="material-symbols-outlined" aria-hidden="true">dashboard</span> Dashboard
            </a>
          <% else %>
            <button
              phx-click="back_to_search"
              class="flex items-center gap-2 text-sm font-bold text-slate-600 hover:text-[#FF4C00] transition"
            >
              <span class="material-symbols-outlined" aria-hidden="true">language</span> Language
            </button>
          <% end %>
          <%!-- User Auth Links --%>
          <%= if @current_user do %>
            <a
              href="/user/logout"
              class="text-sm font-bold text-slate-600 hover:text-[#FF4C00] transition"
            >Logout</a>
          <% else %>
            <a
              href="/user/signup"
              class="text-sm font-bold text-slate-600 hover:text-[#FF4C00] transition"
            >Sign up</a>
            <a
              href="/user/login"
              class="bg-[#FF4C00] text-white px-8 py-2.5 rounded-full font-bold hover:bg-[#E64400] transition shadow-lg shadow-orange-200"
            >
              Log in
            </a>
          <% end %>
        </div>

        <div class="flex lg:hidden">
          <button
            id="mobile-menu-button"
            phx-click={JS.toggle(to: "#mobile-menu-panel")}
            class="text-slate-900 text-2xl p-2"
            aria-label="Open menu"
            aria-expanded="false"
          >
            <span class="material-symbols-outlined" aria-hidden="true">menu</span>
          </button>
        </div>
      </div>

      <div
        id="mobile-menu-panel"
        class="hidden lg:hidden border-t border-slate-100 bg-white shadow-lg"
      >
        <div class="px-4 py-3 space-y-1">
          <%= if @current_user do %>
            <a
              href="/dashboard"
              class="flex items-center gap-3 px-3 py-3 text-sm font-bold text-slate-700 hover:bg-slate-50 rounded-xl transition"
            >
              <span class="material-symbols-outlined text-[#FF4C00]">dashboard</span> Dashboard
            </a>
            <a
              href="/user/logout"
              class="flex items-center gap-3 px-3 py-3 text-sm font-bold text-slate-700 hover:bg-slate-50 rounded-xl transition"
            >
              <span class="material-symbols-outlined text-slate-500">logout</span> Logout
            </a>
          <% else %>
            <a
              href="/user/signup"
              class="flex items-center gap-3 px-3 py-3 text-sm font-bold text-slate-700 hover:bg-slate-50 rounded-xl transition"
            >
              <span class="material-symbols-outlined text-slate-500">person_add</span> Sign up
            </a>
            <a
              href="/user/login"
              class="flex items-center gap-3 px-3 py-3 text-sm font-bold text-white bg-[#FF4C00] rounded-xl hover:bg-[#E64400] transition"
            >
              <span class="material-symbols-outlined">login</span> Log in
            </a>
          <% end %>
          <a
            href="/"
            class="flex items-center gap-3 px-3 py-3 text-sm font-bold text-slate-700 hover:bg-slate-50 rounded-xl transition"
          >
            <span class="material-symbols-outlined text-slate-500">directions_bus</span> Bus Tickets
          </a>
          <a
            href="/tour-packages"
            class="flex items-center gap-3 px-3 py-3 text-sm font-bold text-slate-700 hover:bg-slate-50 rounded-xl transition"
          >
            <span class="material-symbols-outlined text-slate-500">category</span> Chyllz
          </a>
          <a
            href="/tour-packages/insurance"
            class="flex items-center gap-3 px-3 py-3 text-sm font-bold text-slate-700 hover:bg-slate-50 rounded-xl transition"
          >
            <span class="material-symbols-outlined text-slate-500">shield</span> InSURE
          </a>
          <a
            id="pwa-download-mobile"
            href="#app-section"
            phx-hook=".InstallApp"
            class="pwa-hide-installed flex items-center gap-3 px-3 py-3 text-sm font-bold text-slate-700 hover:bg-slate-50 rounded-xl transition"
          >
            <span class="material-symbols-outlined text-slate-500">download</span> Download App
          </a>
          <a
            id="mobile-track-ticket"
            href="/tickets"
            aria-current={if(@step == :ticket, do: "page", else: nil)}
            class={[
              "flex items-center gap-3 px-3 py-3 text-sm font-black rounded-xl border transition",
              if(@step == :ticket,
                do: "bg-[#FF4C00] text-white border-[#FF4C00]",
                else: "bg-white text-[#FF4C00] border-orange-200 hover:bg-orange-50"
              )
            ]}
          >
            <span class="material-symbols-outlined">confirmation_number</span> Track Ticket
          </a>
        </div>
      </div>
    </header>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".InstallApp">
      // The existing "Download App" link doubles as the PWA install action:
      //   * installable browser  -> open the native install prompt
      //   * iOS Safari           -> show "Add to Home Screen" instructions
      //   * otherwise            -> fall back to the #app-section download area
      //                              (reserved for the future Play Store /
      //                              App Store links), or navigate home to it.
      export default {
        mounted() {
          this.hintId = "pwa-install-hint"
          this.isIOS = () => /iphone|ipad|ipod/i.test(window.navigator.userAgent)

          this.el.addEventListener("click", async event => {
            const prompt = window.__komiutaInstallPrompt

            if (prompt) {
              event.preventDefault()
              prompt.prompt()
              try {
                await prompt.userChoice
              } catch (_error) {
                // The user dismissed the install sheet.
              }
              window.__komiutaInstallPrompt = null
              return
            }

            if (this.isIOS()) {
              event.preventDefault()
              this.showHint()
              return
            }

            // No install prompt available: keep the original behaviour, but make
            // it work from pages that do not render the download section.
            if (!document.getElementById("app-section")) {
              event.preventDefault()
              window.location.assign("/#app-section")
            }
          })
        },
        showHint() {
          const existing = document.getElementById(this.hintId)
          if (existing) {
            existing.hidden = false
            return
          }
          const hint = document.createElement("div")
          hint.id = this.hintId
          hint.className =
            "fixed left-1/2 bottom-6 z-[100] -translate-x-1/2 w-[calc(100%-2rem)] max-w-md rounded-2xl bg-slate-900 px-5 py-4 text-white shadow-2xl cursor-pointer"
          hint.innerHTML =
            '<p class="text-[10px] font-black uppercase tracking-widest text-orange-400 mb-1">Install Komiuta</p>' +
            '<p class="text-sm font-bold leading-snug">Open the browser menu (or Share on iPhone) and choose <span class="text-[#FF4C00]">Add to Home Screen</span> to install the app.</p>'
          hint.addEventListener("click", () => hint.remove())
          document.body.appendChild(hint)
          setTimeout(() => hint.remove(), 9000)
        }
      }
    </script>
    """
  end

  def main_footer(assigns) do
    ~H"""
    <footer class="mx-auto mt-12 max-w-[1350px] pb-16 px-6 font-sans font-bold">
      <div class="flex justify-center mb-16">
        <img
          src="/images/logo_brand.png"
          alt="Komiuta"
          width="190"
          height="52"
          loading="lazy"
          decoding="async"
          class="h-12 w-auto opacity-90"
        />
      </div>

      <div class="mb-20 bg-slate-50/50 rounded-[3rem] p-8 md:p-12 border border-slate-100">
        <div class="flex flex-wrap justify-center gap-4 md:gap-10 mb-12 border-b border-slate-200 pb-6">
          <button
            type="button"
            aria-pressed={@footer_tab == "about"}
            phx-click="change_footer_tab"
            phx-value-tab="about"
            class={[
              "text-xs font-black uppercase tracking-widest pb-2 transition-all",
              @footer_tab == "about" && "text-[#FF4C00] border-b-2 border-[#FF4C00]",
              @footer_tab != "about" && "text-slate-400 hover:text-slate-600"
            ]}
          >About us</button>
          <button
            type="button"
            aria-pressed={@footer_tab == "how"}
            phx-click="change_footer_tab"
            phx-value-tab="how"
            class={[
              "text-xs font-black uppercase tracking-widest pb-2 transition-all",
              @footer_tab == "how" && "text-[#FF4C00] border-b-2 border-[#FF4C00]",
              @footer_tab != "how" && "text-slate-400 hover:text-slate-600"
            ]}
          >How to book</button>
          <button
            type="button"
            aria-pressed={@footer_tab == "track"}
            phx-click="change_footer_tab"
            phx-value-tab="track"
            class={[
              "text-xs font-black uppercase tracking-widest pb-2 transition-all",
              @footer_tab == "track" && "text-[#FF4C00] border-b-2 border-[#FF4C00]",
              @footer_tab != "track" && "text-slate-400 hover:text-slate-600"
            ]}
          >Track Ticket</button>
          <button
            type="button"
            aria-pressed={@footer_tab == "carbon"}
            phx-click="change_footer_tab"
            phx-value-tab="carbon"
            class={[
              "text-xs font-black uppercase tracking-widest pb-2 transition-all",
              @footer_tab == "carbon" && "text-[#FF4C00] border-b-2 border-[#FF4C00]",
              @footer_tab != "carbon" && "text-slate-400 hover:text-slate-600"
            ]}
          >Carbon-neutral ride</button>
          <button
            type="button"
            aria-pressed={@footer_tab == "routes"}
            phx-click="change_footer_tab"
            phx-value-tab="routes"
            class={[
              "text-xs font-black uppercase tracking-widest pb-2 transition-all",
              @footer_tab == "routes" && "text-[#FF4C00] border-b-2 border-[#FF4C00]",
              @footer_tab != "routes" && "text-slate-400 hover:text-slate-600"
            ]}
          >Top routes</button>
          <button
            type="button"
            aria-pressed={@footer_tab == "destinations"}
            phx-click="change_footer_tab"
            phx-value-tab="destinations"
            class={[
              "text-xs font-black uppercase tracking-widest pb-2 transition-all",
              @footer_tab == "destinations" && "text-[#FF4C00] border-b-2 border-[#FF4C00]",
              @footer_tab != "destinations" && "text-slate-400 hover:text-slate-600"
            ]}
          >Popular destinations</button>
        </div>

        <div class="max-w-5xl mx-auto text-center animate-fade-in">
          <%= case @footer_tab do %>
            <% "about" -> %>
              <p class="text-sm md:text-base font-bold text-slate-500 leading-relaxed">
                <span class="text-slate-900">Komiuta</span>
                is East Africa's leading technology-driven bus booking engine. We partner with over
                <span class="text-[#FF4C00]">100+ premier bus operators</span>
                to provide a seamless, secure, and reliable travel experience. Since 2019, we have revolutionized regional transport by digitizing the ticketing process for over
                <span class="text-slate-900">830,000 travelers</span>
                across Kenya, Uganda, and Tanzania. Our mission is to help you
                <span class="text-[#FF4C00]">Elevate Your Journey</span>
                through industrial-grade reliability and user-centric innovation.
              </p>
            <% "how" -> %>
              <div class="grid grid-cols-1 md:grid-cols-3 gap-6 text-left">
                <div class="p-4 bg-white rounded-2xl border border-slate-100 shadow-sm">
                  <div class="text-[#FF4C00] font-black text-xl mb-2">01. Search</div>

                  <p class="text-xs font-bold text-slate-400">
                    Enter your departure city, destination, and travel date to see all available buses instantly.
                  </p>
                </div>

                <div class="p-4 bg-white rounded-2xl border border-slate-100 shadow-sm">
                  <div class="text-[#FF4C00] font-black text-xl mb-2">02. Select</div>

                  <p class="text-xs font-bold text-slate-400">
                    Choose your preferred seat from our interactive bus map and select your pickup/dropoff points.
                  </p>
                </div>

                <div class="p-4 bg-white rounded-2xl border border-slate-100 shadow-sm">
                  <div class="text-[#FF4C00] font-black text-xl mb-2">03. Pay</div>

                  <p class="text-xs font-bold text-slate-400">
                    Complete your booking using M-Pesa, Airtel Money, or Card and receive your E-ticket immediately.
                  </p>
                </div>
              </div>
            <% "track" -> %>
              <p class="text-sm md:text-base font-bold text-slate-500 leading-relaxed">
                Never miss a bus with <span class="text-slate-900">Komiuta Real-Time Tracking</span>. By entering your ticket number in our mobile app, you can see the exact live location of your bus, estimated time of arrival at your boarding point, and receive instant push notifications about any operator changes. Stay informed, stay safe, and travel with total peace of mind.
              </p>
            <% "carbon" -> %>
              <p class="text-sm md:text-base font-bold text-slate-500 leading-relaxed">
                Komiuta is committed to the future of sustainable transport. We are currently pioneering
                <span class="text-[#00AC4E]">Carbon-Neutral Travel</span>
                initiatives in East Africa, including the phased rollout of our first intercity
                <strong class="font-black text-slate-900">EV (Electric Vehicle) fleet</strong>
                by 2025. By choosing Komiuta, you're supporting optimized route planning that reduces fuel waste and helps preserve the beautiful landscapes of our region for future generations.
              </p>
            <% "routes" -> %>
              <div class="flex flex-wrap justify-center gap-3">
                <%= for r <- ["Nairobi to Mombasa", "Mombasa to Nairobi", "Nairobi to Kisumu", "Eldoret to Nairobi", "Nakuru to Nairobi", "Thika to Garissa"] do %>
                  <span class="px-4 py-2 bg-white border border-slate-100 rounded-full text-[10px] font-black uppercase text-slate-600 shadow-sm">#{r}</span>
                <% end %>
              </div>
            <% "destinations" -> %>
              <div class="flex flex-wrap justify-center gap-3">
                <%= for d <- ["Nairobi", "Mombasa", "Kisumu", "Eldoret", "Nakuru", "Malindi", "Ukunda", "Diani", "Kampala", "Arusha"] do %>
                  <span class="px-4 py-2 bg-white border border-slate-100 rounded-full text-[10px] font-black uppercase text-slate-900 shadow-sm">#{d}</span>
                <% end %>
              </div>
          <% end %>

          <a
            href="/tour-packages"
            class="mt-8 text-[#FF4C00] font-black text-xs uppercase tracking-widest hover:underline flex items-center justify-center gap-2 mx-auto transition-all hover:scale-105 w-fit"
          >
            Explore Chyllz packages
            <span class="material-symbols-outlined !text-sm">arrow_forward</span>
          </a>
        </div>
      </div>

      <div class="flex flex-col md:flex-row justify-center items-center gap-10 md:gap-20 text-slate-500 font-bold">
        <a
          href="mailto:hello@komiuta.com"
          class="hover:text-[#FF4C00] transition flex items-center gap-3"
        ><span class="material-symbols-outlined !text-[#FF4C00]">mail</span> hello@komiuta.com</a>
        <a href="tel:0800211211" class="hover:text-[#FF4C00] transition flex items-center gap-3"><span class="material-symbols-outlined !text-[#FF4C00]">call</span>
        0800 211 211</a>
        <span class="flex items-center gap-3"><span class="material-symbols-outlined !text-[#FF4C00]">location_on</span>
        Kenya</span>
      </div>

      <div class="mt-10 flex flex-wrap justify-center gap-6 text-[10px] font-black uppercase tracking-widest text-slate-400">
        <a href="/tickets" class="hover:text-[#FF4C00] transition">Track ticket</a>
        <a href="/terms" class="hover:text-[#FF4C00] transition">Terms &amp; Conditions</a>
        <a href="/privacy" class="hover:text-[#FF4C00] transition">Privacy Policy</a>
      </div>

      <div class="mt-10 pt-10 border-t border-slate-100 text-center">
        <p class="text-[10px] font-black uppercase tracking-[0.5em] text-slate-300">
          © {DateTime.utc_now().year} Komiuta WanCom Engineering Sol. All rights reserved.
        </p>
      </div>
    </footer>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :active, :string, required: true

  def user_tab_link(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="switch_tab"
      phx-value-tab={@id}
      class={[
        "flex items-center gap-2 px-6 py-3 rounded-xl text-sm font-black uppercase tracking-widest transition-all shrink-0",
        @active == @id && "bg-[#FF4C00] text-white shadow-lg shadow-orange-100",
        @active != @id && "text-slate-400 hover:bg-slate-50 hover:text-slate-900"
      ]}
    >
      <span class="material-symbols-outlined !text-xl">{@icon}</span> {@label}
    </button>
    """
  end
end
