defmodule XpressbusWeb.AssistantComponents do
  @moduledoc """
  Presentation for the Chyllz AI assistant.

  The components are intentionally stateless: every piece of interaction state
  (open/closed, active tab, threads, uploads, pending replies) is owned by
  `XpressbusWeb.ChyllzLive`, which keeps the assistant easy to test and avoids
  duplicating the catalogue state in a second process.
  """

  use XpressbusWeb, :html

  @tabs [
    {"chat", "Chat", "chat"},
    {"lens", "Lens", "image"},
    {"receipt", "Receipt", "description"},
    {"food", "Food", "restaurant"}
  ]

  @chyllz_assistant_paths [
    "/tour-packages",
    "/tour-packages/hotels",
    "/our-packages/hidden-gems",
    "/tour-packages/car",
    "/tour-packages/events"
  ]

  @global_launcher_excluded_prefixes [
    "/admin",
    "/agent",
    "/dev",
    "/payments",
    "/review-and-pay",
    "/passenger-details",
    "/payment-processing"
  ]

  @doc """
  True when the site-wide launcher should render for a request path.

  The Chyllz pages already render a live assistant launcher; internal admin/agent
  areas and checkout/payment flows are excluded so the FAB never covers their
  primary actions. Every other public page gets the green launcher.
  """
  def show_global_launcher?(path) when is_binary(path) do
    path =
      path
      |> String.replace(~r/[?#].*$/, "")
      |> String.trim_trailing("/")

    path = if path == "", do: "/", else: path

    path not in @chyllz_assistant_paths and
      not Enum.any?(@global_launcher_excluded_prefixes, &String.starts_with?(path, &1))
  end

  def show_global_launcher?(_path), do: false

  @doc "Green floating sparkle button used on Chyllz pages."
  attr :open, :boolean, required: true

  def assistant_launcher(assigns) do
    ~H"""
    <button
      :if={!@open}
      id="chyllz-assistant-launcher"
      type="button"
      phx-click="assistant_open"
      title="Ask Chyllz AI"
      class="assistant-launcher fixed bottom-5 right-4 z-[70] grid h-14 w-14 place-items-center rounded-full bg-gradient-to-br from-emerald-500 via-emerald-600 to-emerald-800 text-white shadow-2xl shadow-emerald-900/30 transition-all duration-300 hover:-translate-y-0.5 hover:scale-105 hover:shadow-emerald-700/40 sm:bottom-6 sm:right-6"
      aria-label="Open Chyllz AI travel assistant"
      aria-expanded="false"
    >
      <.sparkle_icon class="h-7 w-7" />
      <span class="assistant-live-dot absolute -right-0.5 -top-0.5 h-3 w-3 rounded-full border-2 border-white bg-emerald-300"></span>
    </button>
    """
  end

  @doc """
  Site-wide green launcher for pages that do not mount the Chyllz LiveView.

  It links to the Chyllz assistant with `?assistant=1`, which opens the same
  panel on arrival. The button is visually identical to the Chyllz launcher.
  """
  def global_assistant_launcher(assigns) do
    ~H"""
    <a
      id="global-assistant-launcher"
      href="/tour-packages?assistant=1"
      title="Ask Chyllz AI"
      class="assistant-launcher fixed bottom-5 right-4 z-[70] grid h-14 w-14 place-items-center rounded-full bg-gradient-to-br from-emerald-500 via-emerald-600 to-emerald-800 text-white shadow-2xl shadow-emerald-900/30 transition-all duration-300 hover:-translate-y-0.5 hover:scale-105 hover:shadow-emerald-700/40 sm:bottom-6 sm:right-6"
      aria-label="Open Chyllz AI travel assistant"
      data-track="chat_open"
    >
      <.sparkle_icon class="h-7 w-7" />
      <span class="assistant-live-dot absolute -right-0.5 -top-0.5 h-3 w-3 rounded-full border-2 border-white bg-emerald-300"></span>
    </a>
    """
  end

  attr :open, :boolean, required: true
  attr :tab, :string, required: true
  attr :thread, :list, required: true
  attr :pending, :boolean, default: false
  attr :pending_tab, :string, default: nil
  attr :input, :string, default: ""
  attr :upload, :any, required: true
  attr :caption, :string, default: ""
  attr :receipt_text, :string, default: ""
  attr :expenses, :list, default: []
  attr :expense_total, :string, default: nil
  attr :greeting, :map, required: true
  attr :suggestions, :list, default: []
  attr :engine, :string, default: "Chyllz AI"
  attr :ai_enabled, :boolean, default: false
  attr :error, :string, default: nil

  @doc "The full assistant sheet (hidden off-canvas until opened)."
  def assistant_panel(assigns) do
    assigns =
      assigns
      |> assign(:tabs, @tabs)
      |> assign(:hero, hero_copy(assigns.tab))

    ~H"""
    <div
      id="chyllz-assistant"
      data-open={if @open, do: "true", else: "false"}
      class="fixed inset-0 z-[80]"
      phx-hook=".AssistantFocus"
      phx-window-keydown="assistant_escape"
      phx-key="escape"
    >
      <div
        id="chyllz-assistant-backdrop"
        class="absolute inset-0 bg-slate-950/55 backdrop-blur-[2px]"
        phx-click="assistant_close"
        aria-hidden="true"
      >
      </div>

      <section
        id="chyllz-assistant-panel"
        class="absolute inset-x-0 bottom-0 top-0 flex max-h-none flex-col overflow-hidden bg-white shadow-[0_0_80px_rgba(15,23,42,0.35)] sm:inset-y-0 sm:left-auto sm:right-0 sm:w-[450px] sm:rounded-l-[2rem]"
        role="dialog"
        aria-modal="true"
        aria-label="Chyllz AI travel assistant"
        inert={!@open}
      >
        <header class="shrink-0 border-b border-slate-100 bg-white/95 px-4 pb-3 pt-4 backdrop-blur">
          <div class="grid grid-cols-[1fr_auto_1fr] items-center gap-2">
            <div class="flex items-center gap-1">
              <button
                id="assistant-back"
                type="button"
                phx-click="assistant_close"
                class="grid h-9 w-9 place-items-center rounded-full border border-slate-200 bg-white text-slate-500 transition hover:border-slate-300 hover:text-slate-900"
                aria-label="Close assistant"
              >
                <span class="material-symbols-outlined !text-xl" aria-hidden="true">chevron_left</span>
              </button>
              <button
                id="assistant-new-chat"
                type="button"
                phx-click="assistant_new_chat"
                class="grid h-9 w-9 place-items-center rounded-full border border-slate-200 bg-white text-slate-500 transition hover:border-orange-200 hover:text-[#FF4C00]"
                aria-label="Start a new chat"
                title="New chat"
              >
                <span class="material-symbols-outlined !text-lg" aria-hidden="true">edit_square</span>
              </button>
            </div>

            <div class="flex items-center justify-center gap-2">
              <span class="grid h-7 w-7 place-items-center rounded-[0.65rem] bg-gradient-to-br from-emerald-600 to-emerald-950 text-white shadow-sm">
                <.sparkle_icon class="h-4 w-4" />
              </span>
              <span class="font-heading text-lg font-black tracking-tight text-slate-950">
                Chyllz <span class="text-[#FF4C00]">AI</span>
              </span>
            </div>

            <div class="flex justify-end">
              <button
                id="assistant-close"
                type="button"
                phx-click="assistant_close"
                class="grid h-9 w-9 place-items-center rounded-full border border-slate-200 bg-white text-slate-500 transition hover:border-slate-300 hover:text-slate-900"
                aria-label="Close assistant"
              >
                <span class="material-symbols-outlined !text-xl" aria-hidden="true">close</span>
              </button>
            </div>
          </div>

          <div
            id="assistant-tabs"
            class="mt-4 flex items-center gap-1 rounded-full bg-slate-100 p-1.5"
            role="tablist"
            aria-label="Assistant modes"
          >
            <button
              :for={{key, label, icon} <- @tabs}
              id={"assistant-tab-" <> key}
              type="button"
              role="tab"
              aria-selected={to_string(@tab == key)}
              phx-click="assistant_tab"
              phx-value-tab={key}
              class={[
                "flex flex-1 items-center justify-center gap-1.5 rounded-full px-2 py-2 text-[11px] font-black transition-all duration-200 sm:text-xs",
                if(@tab == key,
                  do: "bg-white text-slate-950 shadow-sm ring-1 ring-slate-200/70",
                  else: "text-slate-500 hover:text-slate-800"
                )
              ]}
            >
              <span class="material-symbols-outlined !text-base" aria-hidden="true">{icon}</span>
              {label}
            </button>
          </div>
        </header>

        <div
          id="assistant-scroll"
          class="assistant-scroll flex-1 overflow-y-auto overscroll-contain bg-white"
          phx-hook=".AssistantScroll"
          data-open={if @open, do: "true", else: "false"}
          data-tab={@tab}
          data-message-count={length(@thread)}
        >
          <div class="px-5 pb-3 pt-7 text-center">
            <div class="assistant-avatar mx-auto mb-4 grid h-14 w-14 place-items-center rounded-[1.35rem] bg-gradient-to-br from-emerald-600 via-emerald-800 to-emerald-950 text-white shadow-xl shadow-emerald-950/25">
              <.sparkle_icon class="h-7 w-7" />
            </div>
            <h2
              id="assistant-hero-title"
              class="font-heading text-2xl font-black tracking-tight text-slate-950"
            >
              {@hero.title} <span class="assistant-sparkle inline-block">✨</span>
            </h2>
            <p
              id="assistant-hero-subtitle"
              class="mx-auto mt-2 max-w-[19rem] text-xs font-bold leading-relaxed text-slate-400"
            >
              {@hero.subtitle}
            </p>
          </div>

          <div
            :if={@error}
            id="assistant-error"
            class="mx-4 mb-3 rounded-2xl border border-red-100 bg-red-50 px-4 py-3 text-xs font-bold text-red-700"
          >
            <div class="flex items-start gap-2">
              <span class="material-symbols-outlined !text-base" aria-hidden="true">warning</span>
              <p>{@error}</p>
            </div>
          </div>

          <.assistant_tools
            :if={@tab in ["lens", "receipt"]}
            tab={@tab}
            upload={@upload}
            caption={@caption}
            receipt_text={@receipt_text}
            pending={@pending}
            expenses={@expenses}
            expense_total={@expense_total}
            ai_enabled={@ai_enabled}
          />

          <div class="space-y-4 px-4 pb-6 pt-1">
            <article id="assistant-greeting" class="flex items-start gap-2.5" data-assistant-message>
              <div class="mt-0.5 grid h-8 w-8 shrink-0 place-items-center rounded-xl bg-gradient-to-br from-emerald-600 to-emerald-950 text-white shadow-sm">
                <.sparkle_icon class="h-4 w-4" />
              </div>
              <div class="max-w-[85%] rounded-[1.35rem] rounded-tl-md border border-slate-100 bg-white px-4 py-3 text-sm font-semibold leading-relaxed text-slate-700 shadow-sm">
                <p class="whitespace-pre-line">{@greeting.text}</p>
              </div>
            </article>

            <.assistant_message :for={message <- @thread} message={message} />

            <div
              :if={@pending and @pending_tab == @tab}
              id="assistant-typing"
              class="flex items-start gap-2.5"
            >
              <div class="mt-0.5 grid h-8 w-8 shrink-0 place-items-center rounded-xl bg-gradient-to-br from-emerald-600 to-emerald-950 text-white shadow-sm">
                <.sparkle_icon class="h-4 w-4" />
              </div>
              <div class="flex items-center gap-1.5 rounded-[1.35rem] rounded-tl-md border border-slate-100 bg-white px-4 py-3.5 shadow-sm">
                <span class="assistant-typing-dot"></span>
                <span class="assistant-typing-dot" style="animation-delay: .15s"></span>
                <span class="assistant-typing-dot" style="animation-delay: .3s"></span>
              </div>
            </div>

            <div
              :if={@thread == [] and @suggestions != []}
              id="assistant-suggestions"
              class="flex flex-col items-center gap-2 pt-2"
            >
              <p class="text-[9px] font-black uppercase tracking-[0.25em] text-slate-300">
                Try asking
              </p>
              <div class="flex flex-wrap justify-center gap-2">
                <button
                  :for={suggestion <- @suggestions}
                  type="button"
                  phx-click="assistant_suggestion"
                  phx-value-prompt={suggestion}
                  class="rounded-full border border-slate-200 bg-white px-3.5 py-2 text-[11px] font-bold text-slate-600 transition hover:-translate-y-0.5 hover:border-orange-200 hover:text-[#FF4C00] hover:shadow-md"
                >
                  {suggestion}
                </button>
              </div>
            </div>
          </div>

          <p class="px-6 pb-5 text-center text-[9px] font-bold leading-relaxed text-slate-300">
            Chyllz AI can make mistakes. Confirm prices and availability before booking.
          </p>
        </div>

        <div class="shrink-0 border-t border-slate-100 bg-white px-4 pb-[max(0.9rem,env(safe-area-inset-bottom))] pt-3">
          <form id="assistant-chat-form" phx-submit="assistant_send" class="flex items-end gap-2">
            <div class="flex-1 rounded-[1.45rem] border border-slate-200 bg-slate-50 px-4 py-1 transition focus-within:border-orange-300 focus-within:bg-white focus-within:shadow-sm">
              <input
                id="assistant-input"
                type="text"
                name="message"
                value={@input}
                phx-change="assistant_input"
                phx-debounce="150"
                autocomplete="off"
                maxlength="1000"
                placeholder={composer_placeholder(@tab)}
                class="w-full bg-transparent py-2.5 text-sm font-semibold text-slate-900 outline-none placeholder:font-medium placeholder:text-slate-400"
                aria-label="Type your message"
              />
            </div>

            <button
              id="assistant-send"
              type="submit"
              disabled={@pending or String.trim(@input) == ""}
              class="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-[#FF4C00] text-white shadow-lg shadow-orange-200 transition hover:-translate-y-0.5 hover:bg-[#E64400] disabled:translate-y-0 disabled:cursor-not-allowed disabled:bg-slate-200 disabled:text-slate-400 disabled:shadow-none"
              aria-label="Send message"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="h-5 w-5 -rotate-45"
                aria-hidden="true"
              >
                <path d="M22 2 11 13" />
                <path d="M22 2 15 22l-4-9-9-4z" />
              </svg>
            </button>
          </form>

          <p
            id="assistant-engine-label"
            class="mt-2 text-center text-[9px] font-black uppercase tracking-[0.2em] text-slate-300"
          >
            {@engine}
            <span class="mx-1 text-slate-200">·</span>
            {if @ai_enabled, do: "AI + live catalogue", else: "Live catalogue guide"}
          </p>
        </div>
      </section>
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".AssistantFocus">
      export default {
        mounted() {
          this.open = this.el.dataset.open === "true"
          if (this.open) this.focusInput()
        },
        updated() {
          const open = this.el.dataset.open === "true"
          if (open && !this.open) window.setTimeout(() => this.focusInput(), 60)
          this.open = open
        },
        focusInput() {
          const input = document.querySelector("#assistant-input")
          if (input) input.focus({preventScroll: true})
        }
      }
    </script>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".AssistantScroll">
      export default {
        mounted() {
          this.count = Number(this.el.dataset.messageCount || 0)
          this.open = this.el.dataset.open === "true"
          this.tab = this.el.dataset.tab
        },
        updated() {
          const count = Number(this.el.dataset.messageCount || 0)
          const open = this.el.dataset.open === "true"
          const tab = this.el.dataset.tab
          const justOpened = open && !this.open
          const tabChanged = tab !== this.tab

          this.open = open
          this.tab = tab

          if (tabChanged) {
            this.count = count
            this.el.scrollTop = 0
            return
          }

          if (count !== this.count || (justOpened && count > 0)) {
            this.count = count
            this.scrollToBottom()
          }
        },
        scrollToBottom() {
          this.el.scrollTop = this.el.scrollHeight
        }
      }
    </script>
    """
  end

  attr :message, :map, required: true

  defp assistant_message(assigns) do
    ~H"""
    <article
      id={@message.id}
      data-assistant-message
      class={["flex items-start gap-2.5", @message.role == :user && "justify-end"]}
    >
      <div
        :if={@message.role == :assistant}
        class="mt-0.5 grid h-8 w-8 shrink-0 place-items-center rounded-xl bg-gradient-to-br from-emerald-600 to-emerald-950 text-white shadow-sm"
      >
        <.sparkle_icon class="h-4 w-4" />
      </div>

      <div class={[
        "max-w-[85%] rounded-[1.35rem] px-4 py-3 text-sm font-semibold leading-relaxed shadow-sm",
        if(@message.role == :user,
          do: "rounded-tr-md bg-[#FF4C00] text-white shadow-orange-200",
          else: "rounded-tl-md border border-slate-100 bg-white text-slate-700"
        )
      ]}>
        <p class="whitespace-pre-line">{@message.text}</p>

        <div :if={@message.cards != []} class="mt-3 space-y-2">
          <a
            :for={card <- @message.cards}
            href={card.href}
            class="group flex items-center gap-3 rounded-2xl border border-slate-100 bg-slate-50 p-2.5 text-left transition hover:border-orange-200 hover:bg-white hover:shadow-md"
          >
            <span class="grid h-14 w-14 shrink-0 place-items-center overflow-hidden rounded-xl bg-gradient-to-br from-slate-200 to-slate-300">
              <img
                :if={card.image}
                src={card.image}
                alt=""
                loading="lazy"
                class="h-full w-full object-cover"
              />
              <span
                :if={!card.image}
                class="material-symbols-outlined !text-xl text-white"
                aria-hidden="true"
              >
                {card_icon(card.kind)}
              </span>
            </span>
            <span class="min-w-0 flex-1">
              <span class="block truncate text-xs font-black text-slate-900">{card.title}</span>
              <span class="block truncate text-[10px] font-bold text-slate-400">{card.subtitle}</span>
              <span :if={card.price} class="mt-0.5 block text-[10px] font-black text-[#FF4C00]">
                {card.price}
              </span>
            </span>
            <span
              class="material-symbols-outlined shrink-0 text-slate-300 transition group-hover:translate-x-0.5 group-hover:text-[#FF4C00] !text-lg"
              aria-hidden="true"
            >
              arrow_forward
            </span>
          </a>
        </div>

        <div :if={@message.action} class="mt-3">
          <button
            :if={@message.action[:tab]}
            type="button"
            phx-click="assistant_tab"
            phx-value-tab={@message.action.tab}
            class="inline-flex items-center gap-1.5 rounded-full bg-[#FF4C00] px-4 py-2 text-[10px] font-black uppercase tracking-widest text-white transition hover:bg-[#E64400]"
          >
            {@message.action.label}
            <span class="material-symbols-outlined !text-sm" aria-hidden="true">arrow_forward</span>
          </button>

          <a
            :if={!@message.action[:tab]}
            href={@message.action.href}
            class="inline-flex items-center gap-1.5 rounded-full bg-[#FF4C00] px-4 py-2 text-[10px] font-black uppercase tracking-widest text-white transition hover:bg-[#E64400]"
          >
            {@message.action.label}
            <span class="material-symbols-outlined !text-sm" aria-hidden="true">arrow_forward</span>
          </a>
        </div>
      </div>
    </article>
    """
  end

  attr :tab, :string, required: true
  attr :upload, :any, required: true
  attr :caption, :string, default: ""
  attr :receipt_text, :string, default: ""
  attr :pending, :boolean, default: false
  attr :expenses, :list, default: []
  attr :expense_total, :string, default: nil
  attr :ai_enabled, :boolean, default: false

  defp assistant_tools(assigns) do
    ~H"""
    <div
      id={"assistant-tools-" <> @tab}
      class="mx-4 mb-2 rounded-[1.6rem] border border-slate-100 bg-slate-50/80 p-4"
    >
      <div class="flex items-start justify-between gap-3">
        <div>
          <p class="text-[9px] font-black uppercase tracking-[0.25em] text-slate-400">
            {tool_kicker(@tab)}
          </p>
          <p class="mt-1 text-sm font-black text-slate-900">{tool_title(@tab)}</p>
          <p class="mt-1 text-[11px] font-bold leading-relaxed text-slate-400">
            {tool_hint(@tab, @ai_enabled)}
          </p>
        </div>
        <span class="grid h-10 w-10 shrink-0 place-items-center rounded-2xl bg-white text-[#FF4C00] shadow-sm">
          <span class="material-symbols-outlined !text-xl" aria-hidden="true">
            {if @tab == "lens", do: "image", else: "description"}
          </span>
        </span>
      </div>

      <form
        id="assistant-photo-form"
        phx-submit="assistant_analyze"
        phx-change="assistant_validate_upload"
        class="mt-4 space-y-3"
      >
        <label
          for={@upload.ref}
          class="flex cursor-pointer items-center gap-3 rounded-2xl border border-dashed border-slate-300 bg-white/70 px-4 py-3 transition hover:border-orange-300 hover:bg-white"
        >
          <span class="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-orange-50 text-[#FF4C00]">
            <span class="material-symbols-outlined !text-xl" aria-hidden="true">add</span>
          </span>
          <span class="min-w-0">
            <span class="block text-xs font-black text-slate-800">Add a photo</span>
            <span class="block text-[10px] font-bold text-slate-400">JPG, PNG or WebP · up to 8 MB</span>
          </span>
        </label>

        <.live_file_input upload={@upload} class="assistant-file-input" />

        <div :if={@upload.entries != []} class="space-y-2">
          <div
            :for={entry <- @upload.entries}
            class="relative overflow-hidden rounded-2xl border border-slate-200 bg-white"
          >
            <.live_img_preview entry={entry} class="h-36 w-full object-cover" />
            <div class="flex items-center justify-between gap-2 px-3 py-2">
              <p class="truncate text-[10px] font-bold text-slate-500">{entry.client_name}</p>
              <button
                type="button"
                phx-click="assistant_cancel_upload"
                phx-value-ref={entry.ref}
                class="text-[10px] font-black uppercase tracking-widest text-slate-400 transition hover:text-red-500"
              >
                Remove
              </button>
            </div>
          </div>

          <p
            :for={error <- upload_errors(@upload)}
            class="text-[10px] font-bold text-red-600"
          >
            {upload_error_text(error)}
          </p>

          <div :for={entry <- @upload.entries}>
            <p
              :for={error <- upload_errors(@upload, entry)}
              class="text-[10px] font-bold text-red-600"
            >
              {upload_error_text(error)}
            </p>
          </div>
        </div>

        <input
          id="assistant-caption"
          type="text"
          name="caption"
          value={@caption}
          phx-change="assistant_caption"
          phx-debounce="250"
          maxlength="300"
          placeholder="Optional: what should I look for?"
          class="w-full rounded-xl border border-slate-200 bg-white px-3.5 py-2.5 text-xs font-semibold text-slate-800 outline-none transition placeholder:text-slate-400 focus:border-orange-300"
          aria-label="Photo note"
        />

        <button
          type="submit"
          id="assistant-analyze-photo"
          disabled={@pending or @upload.entries == []}
          class="flex w-full items-center justify-center gap-2 rounded-full bg-slate-950 px-4 py-3 text-[10px] font-black uppercase tracking-widest text-white transition hover:bg-slate-800 disabled:cursor-not-allowed disabled:bg-slate-200 disabled:text-slate-400"
        >
          <.sparkle_icon class="h-4 w-4" />
          {if @tab == "lens", do: "Match this photo", else: "Read this receipt"}
        </button>
      </form>

      <form
        :if={@tab == "receipt"}
        id="assistant-receipt-form"
        phx-submit="assistant_receipt_text"
        class="mt-4 space-y-2 border-t border-slate-200 pt-4"
      >
        <label
          for="assistant-receipt-text"
          class="text-[9px] font-black uppercase tracking-[0.25em] text-slate-400"
        >
          Prefer typing?
        </label>
        <textarea
          id="assistant-receipt-text"
          name="receipt_text"
          rows="3"
          maxlength="4000"
          placeholder="Chapati 120&#10;Tilapia 850&#10;Total 970"
          class="w-full resize-none rounded-xl border border-slate-200 bg-white px-3.5 py-2.5 text-xs font-semibold text-slate-800 outline-none transition placeholder:text-slate-400 focus:border-orange-300"
        >{@receipt_text}</textarea>
        <button
          type="submit"
          id="assistant-read-receipt"
          disabled={@pending}
          class="w-full rounded-full border border-slate-200 bg-white px-4 py-2.5 text-[10px] font-black uppercase tracking-widest text-slate-700 transition hover:border-orange-200 hover:text-[#FF4C00] disabled:cursor-not-allowed disabled:opacity-50"
        >
          Read pasted receipt
        </button>
      </form>

      <div
        :if={@tab == "receipt" and @expenses != []}
        id="assistant-expense-log"
        class="mt-4 rounded-2xl border border-emerald-100 bg-emerald-50/70 px-4 py-3"
      >
        <div class="flex items-center justify-between gap-3">
          <div>
            <p class="text-[9px] font-black uppercase tracking-[0.2em] text-emerald-700">
              Trip spend logged
            </p>
            <p id="assistant-expense-total" class="mt-0.5 text-lg font-black text-emerald-900">
              {@expense_total}
            </p>
          </div>
          <div class="text-right">
            <p class="text-[10px] font-bold text-emerald-700">
              {length(@expenses)} {if length(@expenses) == 1, do: "receipt", else: "receipts"}
            </p>
            <button
              type="button"
              phx-click="assistant_clear_expenses"
              class="mt-1 text-[9px] font-black uppercase tracking-widest text-emerald-700/70 underline-offset-2 hover:underline"
            >
              Clear log
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp hero_copy("chat") do
    %{
      title: "Ask Chyllz",
      subtitle: "Your travel companion for spontaneous adventures across East Africa."
    }
  end

  defp hero_copy("lens") do
    %{
      title: "Travel Lens",
      subtitle: "Show me a place, stay or vibe and I'll match it to real Chyllz picks."
    }
  end

  defp hero_copy("receipt") do
    %{
      title: "Trip Receipts",
      subtitle: "Snap or paste a receipt and keep a clean running total of your trip spend."
    }
  end

  defp hero_copy("food") do
    %{
      title: "Taste Chyllz",
      subtitle: "Tell me where you are and what you're craving — I'll find the flavour."
    }
  end

  defp hero_copy(_tab) do
    %{
      title: "Ask Chyllz",
      subtitle: "Your travel companion for spontaneous adventures across East Africa."
    }
  end

  defp composer_placeholder("chat"), do: "Type your message here"
  defp composer_placeholder("lens"), do: "Describe the vibe or ask about the photo…"
  defp composer_placeholder("receipt"), do: "Paste receipt lines here…"
  defp composer_placeholder("food"), do: "Where are you, and what are you craving?"
  defp composer_placeholder(_tab), do: "Type your message here"

  defp tool_kicker("lens"), do: "Photo discovery"
  defp tool_kicker("receipt"), do: "Receipt reader"
  defp tool_kicker(_tab), do: "Assistant tool"

  defp tool_title("lens"), do: "Find what you're looking at"
  defp tool_title("receipt"), do: "Turn a receipt into a spend log"
  defp tool_title(_tab), do: "Assistant"

  defp tool_hint("lens", true),
    do: "AI vision reads the photo; add a note for sharper matches."

  defp tool_hint("lens", false),
    do: "Add a note about the photo and I'll match it to the catalogue."

  defp tool_hint("receipt", true),
    do: "A clear photo is enough — or paste the lines below."

  defp tool_hint("receipt", false),
    do: "Paste the receipt lines below and I'll total and categorise them."

  defp tool_hint(_tab, _ai), do: ""

  defp card_icon("hotel"), do: "hotel"
  defp card_icon("hidden_gem"), do: "explore"
  defp card_icon("car_hire"), do: "directions_car"
  defp card_icon("event"), do: "local_activity"
  defp card_icon(_kind), do: "travel_explore"

  defp upload_error_text(:too_large), do: "That photo is too large — 8 MB is the limit."
  defp upload_error_text(:not_accepted), do: "Use a JPG, PNG or WebP image."
  defp upload_error_text(:too_many_files), do: "Add one photo at a time."
  defp upload_error_text(:external), do: "The upload was interrupted. Please try again."
  defp upload_error_text(_error), do: "That photo could not be uploaded."

  attr :class, :string, default: "h-4 w-4"

  @doc """
  Inline four-point sparkle used as the assistant's mark.

  It is deliberately an SVG rather than a Material Symbols glyph so it renders
  even when the self-hosted icon subset has not been regenerated yet.
  """
  def sparkle_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="currentColor"
      class={@class}
      aria-hidden="true"
    >
      <path d="M12 1.8a1 1 0 0 1 .96.72l1.8 6.02 6.02 1.8a1 1 0 0 1 0 1.92l-6.02 1.8-1.8 6.02a1 1 0 0 1-1.92 0l-1.8-6.02-6.02-1.8a1 1 0 0 1 0-1.92l6.02-1.8 1.8-6.02A1 1 0 0 1 12 1.8Z" />
      <path
        d="M19.2 14.6a.6.6 0 0 1 .57.43l.63 2.1 2.1.63a.6.6 0 0 1 0 1.14l-2.1.63-.63 2.1a.6.6 0 0 1-1.14 0l-.63-2.1-2.1-.63a.6.6 0 0 1 0-1.14l2.1-.63.63-2.1a.6.6 0 0 1 .57-.43Z"
        opacity="0.65"
      />
    </svg>
    """
  end
end
