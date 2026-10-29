This is a web application written using the Phoenix web framework.

## Project guidelines

- Use `mix precommit` alias when you are done with all changes and fix any pending issues
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps

### Phoenix v1.8 guidelines

- **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content
- The `MyAppWeb.Layouts` module is aliased in the `my_app_web.ex` file, so you can use it without needing to alias it again
- Anytime you run into errors with no `current_scope` assign:
  - You failed to follow the Authenticated Routes guidelines, or you failed to pass `current_scope` to `<Layouts.app>`
  - **Always** fix the `current_scope` error by moving your routes to the proper `live_session` and ensure you pass `current_scope` as needed
- Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module
- Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will save steps and prevent errors
- If you override the default input classes (`<.input class="myclass px-2 py-1 rounded-lg">)`) class with your own values, no default classes are inherited, so your
custom classes must fully style the input

### JS and CSS guidelines

- **Use Tailwind CSS classes and custom CSS rules** to create polished, responsive, and visually stunning interfaces.
- Tailwindcss v4 **no longer needs a tailwind.config.js** and uses a new import syntax in `app.css`:

      @import "tailwindcss" source(none);
      @source "../css";
      @source "../js";
      @source "../../lib/my_app_web";

- **Always use and maintain this import syntax** in the app.css file for projects generated with `phx.new`
- **Never** use `@apply` when writing raw css
- **Always** manually write your own tailwind-based components instead of using daisyUI for a unique, world-class design
- Out of the box **only the app.js and app.css bundles are supported**
  - You cannot reference an external vendor'd script `src` or link `href` in the layouts
  - You must import the vendor deps into app.js and app.css to use them
  - **Never write inline <script>custom js</script> tags within templates**

## Hero Section

The booking page hero section has fixed settings that must not be changed:

- `pb-[200px]` padding-bottom in `lib/xpressbus_web/live/booking_live.html.heex` - controls hero height to prevent the search section from being pushed too far down
  - `background-size: 100% auto` and `background-position: top center` for `.hero-background` in `assets/css/app.css` - prevents image cropping of the building
- The Chyllz nav item in the header has a circular orange background (`w-12 h-12 rounded-full flex items-center justify-center`) that should not be changed
- The admin sidebar category toggle signs (`+`/`−`) use circular backgrounds (`w-6 h-6 rounded-full bg-white`) with the `ml-auto` alignment to vertically align with nav_item chevrons - do not change the circle dimensions or alignment
- The Chyllz nav item in the header has no circular background, just uses colored icon (`text-[#FF4C00]` when active, `text-slate-400` when inactive)

## User Authentication

- User login page is at `/user/login` (GET) — accepts a **phone number or email address**
- `/user/auth` (POST) emails a **6-digit one-time code** to the account's email; it does **not** create a session yet
- `/user/verify` (GET/POST) is where the code is entered; on success the session is created with `user_id` = user UUID
- `/user/verify/resend` (POST) re-sends a code (60s cooldown, max 5 codes/hour per account)
- Codes: 6 digits, 10-minute expiry, single use, max 5 attempts, HMAC-hashed at rest (`login_codes` table)
- Registration (`/user/signup` → `/user/register`) now **requires a valid email address** — it is the login factor
- Google OAuth (`/auth/google`) remains available and signs in with the Google-verified email
- User logout is at `/user/logout` (GET)
- User dashboard is at `/dashboard`
- User dashboard tabs: `bus` ("My Bus"), `wallet` ("Wallet & Pay"), `transactions` ("History"), `referral` ("Rewards"), `profile` ("Settings"), `chyllz` ("My Chyllz")
- Default dashboard tab is `bus`
- User session uses `user_id`; OTP/Google logins store the user UUID. Legacy code paths may still store the phone number — `Accounts.get_user/1` resolves both
- **Legacy accounts without an email cannot receive codes** — set an email for those users (support/admin) before they need to log in
- In development, outgoing email is captured by the Swoosh Local adapter and visible at `/dev/mailbox`
- Production email provider: `RESEND_API_KEY` (recommended) or `MAILGUN_API_KEY` + `MAILGUN_DOMAIN` or `BREVO_API_KEY`, plus `MAILER_FROM`. **Render blocks outbound SMTP**, so mailbox/SMTP credentials cannot be used there — use an HTTP email API. Verify delivery with `mix komiuta.send_test_email --to you@example.com`

### Header Auth Rules

All header authentication logic is centralized in `lib/xpressbus_web/components/brand_components.ex` inside `main_header/1`. All pages render the header via `<.main_header step={@step} current_user={@current_user} />`, so the rules below apply globally.

- **Logged in (`current_user` is present):**
  - **Landing page (`step == :search`):** Show **Dashboard** pill, hide Language button, hide Sign up/Log in buttons
  - **Other pages:** Hide Language button, hide Sign up/Log in buttons, show Logout link only
- **Logged out (`current_user` is nil):**
  - Show Language button on all pages
  - Show Sign up and Log in buttons on all pages

### UI/UX & design guidelines

- **Produce world-class UI designs** with a focus on usability, aesthetics, and modern design principles
- Implement **subtle micro-interactions** (e.g., button hover effects, and smooth transitions)
- Ensure **clean typography, spacing, and layout balance** for a refined, premium look
- Focus on **delightful details** like hover effects, loading states, and smooth page transitions


<!-- usage-rules-start -->

<!-- phoenix:elixir-start -->
## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
  you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie:

      # INVALID: we are rebinding inside the `if` and the result never gets assigned
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: we rebind the result of the `if` to a new variable
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason

## Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests
- **Avoid** `Process.sleep/1` and `Process.alive?/1` in tests
  - Instead of sleeping to wait for a process to finish, **always** use `Process.monitor/1` and assert on the DOWN message:

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

   - Instead of sleeping to synchronize before the next call, **always** use `_ = :sys.get_state/1` to ensure the process has handled prior messages
<!-- phoenix:elixir-end -->

<!-- phoenix:phoenix-start -->
## Phoenix guidelines

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.

- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias, ie:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser

        live "/users", UserLive, :index
      end

  the UserLive route would point to the `AppWeb.Admin.UserLive` module

- `Phoenix.View` no longer is needed or included with Phoenix, don't use it
<!-- phoenix:phoenix-end -->

<!-- phoenix:html-start -->
## Phoenix HTML guidelines

- Phoenix templates **always** use `~H` or .html.heex files (known as HEEx), **never** use `~E`
- **Always** use the imported `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1` function to build forms. **Never** use `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for` as they are outdated
- When building forms **always** use the already imported `Phoenix.Component.to_form/2` (`assign(socket, form: to_form(...))` and `<.form for={@form} id="msg-form">`), then access those forms in the template via `@form[:field]`
- **Always** add unique DOM IDs to key elements (like forms, buttons, etc) when writing templates, these IDs can later be used in tests (`<.form for={@form} id="product-form">`)
- For "app wide" template imports, you can import/alias into the `my_app_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponent's, and all modules that do `use MyAppWeb, :html` (replace "my_app" by the actual app name)

- Elixir supports `if/else` but **does NOT support `if/else if` or `if/elsif`**. **Never use `else if` or `elseif` in Elixir**, **always** use `cond` or `case` for multiple conditionals.

  **Never do this (invalid)**:

      <%= if condition do %>
        ...
      <% else if other_condition %>
        ...
      <% end %>

  Instead **always** do this:

      <%= cond do %>
        <% condition -> %>
          ...
        <% condition2 -> %>
          ...
        <% true -> %>
          ...
      <% end %>

- HEEx require special tag annotation if you want to insert literal curly's like `{` or `}`. If you want to show a textual code snippet on the page in a `<pre>` or `<code>` block you *must* annotate the parent tag with `phx-no-curly-interpolation`:

      <code phx-no-curly-interpolation>
        let obj = {key: "val"}
      </code>

  Within `phx-no-curly-interpolation` annotated tags, you can use `{` and `}` without escaping them, and dynamic Elixir expressions can still be used with `<%= ... %>` syntax

- HEEx class attrs support lists, but you must **always** use list `[...]` syntax. You can use the class list syntax to conditionally add classes, **always do this for multiple class values**:

      <a class={[
        "px-2 text-white",
        @some_flag && "py-5",
        if(@other_condition, do: "border-red-500", else: "border-blue-100"),
        ...
      ]}>Text</a>

  and **always** wrap `if`'s inside `{...}` expressions with parens, like done above (`if(@other_condition, do: "...", else: "...")`)

  and **never** do this, since it's invalid (note the missing `[` and `]`):

      <a class={
        "px-2 text-white",
        @some_flag && "py-5"
      }> ...
      => Raises compile syntax error on invalid HEEx attr syntax

- **Never** use `<% Enum.each %>` or non-for comprehensions for generating template content, instead **always** use `<%= for item <- @collection do %>`
- HEEx HTML comments use `<%!-- comment --%>`. **Always** use the HEEx HTML comment syntax for template comments (`<%!-- comment --%>`)
- HEEx allows interpolation via `{...}` and `<%= ... %>`, but the `<%= %>` **only** works within tag bodies. **Always** use the `{...}` syntax for interpolation within tag attributes, and for interpolation of values within tag bodies. **Always** interpolate block constructs (if, cond, case, for) within tag bodies using `<%= ... %>`.

  **Always** do this:

      <div id={@id}>
        {@my_assign}
        <%= if @some_block_condition do %>
          {@another_assign}
        <% end %>
      </div>

  and **Never** do this – the program will terminate with a syntax error:

      <%!-- THIS IS INVALID NEVER EVER DO THIS --%>
      <div id="<%= @invalid_interpolation %>">
        {if @invalid_block_construct do}
        {end}
      </div>
<!-- phoenix:html-end -->

<!-- phoenix:liveview-start -->
## Phoenix LiveView guidelines

- **Never** use the deprecated `live_redirect` and `live_patch` functions, instead **always** use the `<.link navigate={href}>` and  `<.link patch={href}>` in templates, and `push_navigate` and `push_patch` functions LiveViews
- **Avoid LiveComponent's** unless you have a strong, specific need for them
- LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. When you go to add LiveView routes to the router, the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`

### LiveView streams

- **Always** use LiveView streams for collections for assigning regular lists to avoid memory ballooning and runtime termination with the following operations:
  - basic append of N items - `stream(socket, :messages, [new_msg])`
  - resetting stream with new items - `stream(socket, :messages, [new_msg], reset: true)` (e.g. for filtering items)
  - prepend to stream - `stream(socket, :messages, [new_msg], at: -1)`
  - deleting items - `stream_delete(socket, :messages, msg)`

- When using the `stream/3` interfaces in the LiveView, the LiveView template must 1) always set `phx-update="stream"` on the parent element, with a DOM id on the parent element like `id="messages"` and 2) consume the `@streams.stream_name` collection and use the id as the DOM id for each child. For a call like `stream(socket, :messages, [new_msg])` in the LiveView, the template would be:

      <div id="messages" phx-update="stream">
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>

- LiveView streams are *not* enumerable, so you cannot use `Enum.filter/2` or `Enum.reject/2` on them. Instead, if you want to filter, prune, or refresh a list of items on the UI, you **must refetch the data and re-stream the entire stream collection, passing reset: true**:

      def handle_event("filter", %{"filter" => filter}, socket) do
        # re-fetch the messages based on the filter
        messages = list_messages(filter)

        {:noreply,
         socket
         |> assign(:messages_empty?, messages == [])
         # reset the stream with the new messages
         |> stream(:messages, messages, reset: true)}
      end

- LiveView streams *do not support counting or empty states*. If you need to display a count, you must track it using a separate assign. For empty states, you can use Tailwind classes:

      <div id="tasks" phx-update="stream">
        <div class="hidden only:block">No tasks yet</div>
        <div :for={{id, task} <- @streams.tasks} id={id}>
          {task.name}
        </div>
      </div>

  The above only works if the empty state is the only HTML block alongside the stream for-comprehension.

- When updating an assign that should change content inside any streamed item(s), you MUST re-stream the items
  along with the updated assign:

      def handle_event("edit_message", %{"message_id" => message_id}, socket) do
        message = Chat.get_message!(message_id)
        edit_form = to_form(Chat.change_message(message, %{content: message.content}))

        # re-insert message so @editing_message_id toggle logic takes effect for that stream item
        {:noreply,
         socket
         |> stream_insert(:messages, message)
         |> assign(:editing_message_id, String.to_integer(message_id))
         |> assign(:edit_form, edit_form)}
      end

  And in the template:

      <div id="messages" phx-update="stream">
        <div :for={{id, message} <- @streams.messages} id={id} class="flex group">
          {message.username}
          <%= if @editing_message_id == message.id do %>
            <%!-- Edit mode --%>
            <.form for={@edit_form} id="edit-form-#{message.id}" phx-submit="save_edit">
              ...
            </.form>
          <% end %>
        </div>
      </div>

- **Never** use the deprecated `phx-update="append"` or `phx-update="prepend"` for collections

### LiveView JavaScript interop

- Remember anytime you use `phx-hook="MyHook"` and that JS hook manages its own DOM, you **must** also set the `phx-update="ignore"` attribute
- **Always** provide an unique DOM id alongside `phx-hook` otherwise a compiler error will be raised

LiveView hooks come in two flavors, 1) colocated js hooks for "inline" scripts defined inside HEEx,
and 2) external `phx-hook` annotations where JavaScript object literals are defined and passed to the `LiveSocket` constructor.

#### Inline colocated js hooks

**Never** write raw embedded `<script>` tags in heex as they are incompatible with LiveView.
Instead, **always use a colocated js hook script tag (`:type={Phoenix.LiveView.ColocatedHook}`)
when writing scripts inside the template**:

    <input type="text" name="user[phone_number]" id="user-phone-number" phx-hook=".PhoneNumber" />
    <script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneNumber">
      export default {
        mounted() {
          this.el.addEventListener("input", e => {
            let match = this.el.value.replace(/\D/g, "").match(/^(\d{3})(\d{3})(\d{4})$/)
            if(match) {
              this.el.value = `${match[1]}-${match[2]}-${match[3]}`
            }
          })
        }
      }
    </script>

- colocated hooks are automatically integrated into the app.js bundle
- colocated hooks names **MUST ALWAYS** start with a `.` prefix, i.e. `.PhoneNumber`

#### External phx-hook

External JS hooks (`<div id="myhook" phx-hook="MyHook">`) must be placed in `assets/js/` and passed to the
LiveSocket constructor:

    const MyHook = {
      mounted() { ... }
    }
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: { MyHook }
    });

#### Pushing events between client and server

Use LiveView's `push_event/3` when you need to push events/data to the client for a phx-hook to handle.
**Always** return or rebind the socket on `push_event/3` when pushing events:

    # re-bind socket so we maintain event state to be pushed
    socket = push_event(socket, "my_event", %{...})

    # or return the modified socket directly:
    def handle_event("some_event", _, socket) do
      {:noreply, push_event(socket, "my_event", %{...})}
    end

Pushed events can then be picked up in a JS hook with `this.handleEvent`:

    mounted() {
      this.handleEvent("my_event", data => console.log("from server:", data));
    }

Clients can also push an event to the server and receive a reply with `this.pushEvent`:

    mounted() {
      this.el.addEventListener("click", e => {
        this.pushEvent("my_event", { one: 1 }, reply => console.log("got reply from server:", reply));
      })
    }

Where the server handled it via:

    def handle_event("my_event", %{"one" => 1}, socket) do
      {:reply, %{two: 2}, socket}
    end

### LiveView tests

- `Phoenix.LiveViewTest` module and `LazyHTML` (included) for making your assertions
- Form tests are driven by `Phoenix.LiveViewTest`'s `render_submit/2` and `render_change/2` functions
- Come up with a step-by-step test plan that splits major test cases into small, isolated files. You may start with simpler tests that verify content exists, gradually add interaction tests
- **Always reference the key element IDs you added in the LiveView templates in your tests** for `Phoenix.LiveViewTest` functions like `element/2`, `has_element/2`, selectors, etc
- **Never** tests again raw HTML, **always** use `element/2`, `has_element/2`, and similar: `assert has_element?(view, "#my-form")`
- Instead of relying on testing text content, which can change, favor testing for the presence of key elements
- Focus on testing outcomes rather than implementation details
- Be aware that `Phoenix.Component` functions like `<.form>` might produce different HTML than expected. Test against the output HTML structure, not your mental model of what you expect it to be
- When facing test failures with element selectors, add debug statements to print the actual HTML, but use `LazyHTML` selectors to limit the output, ie:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")

### Form handling

#### Creating a form from params

If you want to create a form based on `handle_event` params:

    def handle_event("submitted", params, socket) do
      {:noreply, assign(socket, form: to_form(params))}
    end

When you pass a map to `to_form/1`, it assumes said map contains the form params, which are expected to have string keys.

You can also specify a name to nest the params:

    def handle_event("submitted", %{"user" => user_params}, socket) do
      {:noreply, assign(socket, form: to_form(user_params, as: :user))}
    end

#### Creating a form from changesets

When using changesets, the underlying data, form params, and errors are retrieved from it. The `:as` option is automatically computed too. E.g. if you have a user schema:

    defmodule MyApp.Users.User do
      use Ecto.Schema
      ...
    end

And then you create a changeset that you pass to `to_form`:

    %MyApp.Users.User{}
    |> Ecto.Changeset.change()
    |> to_form()

Once the form is submitted, the params will be available under `%{"user" => user_params}`.

In the template, the form form assign can be passed to the `<.form>` function component:

    <.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
      <.input field={@form[:field]} type="text" />
    </.form>

Always give the form an explicit, unique DOM ID, like `id="todo-form"`.

#### Avoiding form errors

**Always** use a form assigned via `to_form/2` in the LiveView, and the `<.input>` component in the template. In the template **always access forms this**:

    <%!-- ALWAYS do this (valid) --%>
    <.form for={@form} id="my-form">
      <.input field={@form[:field]} type="text" />
    </.form>

And **never** do this:

    <%!-- NEVER do this (invalid) --%>
    <.form for={@changeset} id="my-form">
      <.input field={@changeset[:field]} type="text" />
    </.form>

- You are FORBIDDEN from accessing the changeset in the template as it will cause errors
- **Never** use `<.form let={f} ...>` in the template, instead **always use `<.form for={@form} ...>`**, then drive all form references from the form assign as in `@form[:field]`. The UI should **always** be driven by a `to_form/2` assigned in the LiveView module that is derived from a changeset
<!-- phoenix:liveview-end -->

<!-- usage-rules-end -->

---

## Safe Update & Rollback Protocol

Any AI agent modifying this codebase **MUST** follow this protocol to prevent breaking the system and ensure automatic recovery.

### Golden Rules

1. **NEVER overwrite the only working copy of code without a backup or rollback plan.**
2. **ALWAYS preserve the ability to restore the last functional state.**
3. **If a change breaks the system and cannot be fixed, automatically roll back to the last known functional commit or backup.**

### Before Making Changes

1. **Identify the current functional baseline:**
   - Run `git status` to check for uncommitted changes.
   - If the working tree is clean, note the current commit hash (`git rev-parse HEAD`).
   - If there are uncommitted changes that are functional, commit them first or stash them (`git stash push -m "pre-agent-backup"`).

2. **Create a rollback point:**
   - If using Git, create a temporary branch or tag: `git checkout -b backup-before-agent-changes` or `git tag backup-before-agent-changes`.
   - If Git is not available, copy the entire project directory to a backup location (e.g., `backup_YYYYMMDD_HHMMSS/`).

3. **Verify the current state is functional:**
   - Run the project's test suite or build/lint commands (e.g., `mix test`, `npm run build`, etc.).
   - Ensure the application starts without errors.
   - If tests fail before changes, **STOP** and report that the baseline is already broken.

### During Changes

1. **Make incremental, small changes.** Do not refactor and add features in the same step.
2. **After each significant change, run relevant tests or linters.**
3. **Commit frequently** with descriptive messages after each verified working state.

### After Changes

1. **Run the full test suite and verification commands.**
2. **If everything passes**, the update is successful.
3. **If something breaks**:
   - Attempt to fix the issue.
   - If the issue **cannot be fixed** after reasonable effort, or if the user explicitly requests rollback:
     - **Git projects**: `git reset --hard backup-before-agent-changes` (or checkout the backup branch/tag).
     - **Non-Git projects**: Restore files from the backup directory.
     - **Delete the backup branch/tag after successful rollback** if desired.

### Emergency Rollback (System is Broken)

If the system is completely broken (e.g., application will not start, tests fail catastrophically):

1. **Do not attempt further speculative changes.**
2. **Execute rollback immediately:**
   - `git reset --hard HEAD~1` (if the last commit broke it) or `git reset --hard backup-before-agent-changes`.
   - Restore from the dated backup directory if Git is unavailable.
3. **Verify the rollback succeeded** by running tests or starting the application.
4. **Report to the user:**
   - What was attempted.
   - Why it failed.
   - What was rolled back to.
   - Suggestions for how to proceed safely.

### Prohibited Actions

- **NEVER** force-push or rewrite public/shared history without explicit user approval.
- **NEVER** delete backups or rollback points until the user confirms the new state is stable.
- **NEVER** make changes that remove core functionality without an explicit replacement being verified first.
- **NEVER** assume dependencies are installed; verify before referencing them.

## Development Logs

### 2026-09-04 Session

**Objective:** Fix broken/unfunctional code and production-grade the loading and security of the Xpressbus Phoenix app without changing UI/UX.

**Completed:**
- Fixed duplicate config blocks in `config/runtime.exs` (removed 2 duplicate occurrences)
- Fixed duplicate config blocks in `config/test.exs` (removed 2 duplicate occurrences)
- Added Ecto Repo database configuration to `config/test.exs` for MariaDB on port 3307
- Created missing `test/support/data_case.ex` with SQL sandbox setup
- Replaced `IO.puts` with `Logger.info` in `lib/xpressbus/routes/seeder.ex`
- Verified `config/prod.exs` is clean (no duplicate blocks)

**Current State:**
- `mix compile --warnings-as-errors` passes
- `mix format --check-formatted` passes
- `mix test` should now work with proper database config and DataCase module

**Next Agent Guidance:**
- Run `mix test` to verify all tests pass
- Run `mix precommit` to verify all checks pass
- Review `UserDashboardLive` for any remaining issues
- Check for any other `IO.puts` usage in production code that should use `Logger`
- Verify `SECRET_KEY_BASE` is set in production environment variables

### 2026-10-29 Session — Chyllz & InSURE catalogue moved from demo content to the database

**Objective:** The Chyllz pages and the InSURE page still rendered hard-coded demo content. Make them
production pages backed by the database, with no visual regression.

**Completed:**
- Added `Xpressbus.Chyllz` — read-only catalogue queries (hotels, hidden gems, car hires, events) used by
  the public Chyllz pages. Only `active` rows are returned, duplicates are collapsed by natural key, and
  every query is bounded by a limit.
- Rewrote `ChyllzLive`: all five routes (`/tour-packages`, `/tour-packages/hotels`,
  `/our-packages/hidden-gems`, `/tour-packages/car`, `/tour-packages/events`) render database content,
  per-page heroes, real server-side search (`?q=`, patched URLs), result counts, empty states and a
  detail dialog whose CTA links into bus search prefilled with the destination.
- Added the `insurance_plans` and `insurance_faqs` tables + `Xpressbus.Insurance` context and rewrote
  `InsuranceLive` to render plans, features, the coverage comparison table, FAQs and the cheapest-price
  pitch from the database. Default launch content lives in `Xpressbus.Insurance.SeedData` and is inserted
  idempotently by the migration and by `priv/repo/seeds.exs`.
- Added `active` flags + unique indexes to `hotels`, `hidden_gems`, `car_hires`, `events`; a data migration
  removed the duplicate rows created by re-running the old seeder (21→3 hotels, 21→3 gems, 21→3 cars,
  14→2 events) and `seeds.exs` is now idempotent for these tables.
- Added the read-only `/admin/insurance-plans` catalogue page and its sidebar entry; the header now keeps
  the Chyllz tab highlighted on all Chyllz sub-pages.
- Added 33 tests (catalogue context, insurance context, LiveView coverage of every public page + empty
  states, search, dialog, plan selection). Full suite: 86/86 passing.

**Important config change:** `config/test.exs` now defaults `DB_NAME` to `buupasskomiuta_test`, not the
shared development database. 5 pre-existing tests failed whenever the development database had seed data
because they assert whole-table results; `mix test` now creates and migrates the isolated test database
automatically. CI can still override `DB_NAME`.

**Content management:** to change what the public pages show, edit the catalogue rows (or
`Xpressbus.Insurance.SeedData` for launch defaults) — do not hard-code content in the LiveViews again.
Set a row's `active` to `false` to hide it from the public site.

**Backups (Git is not installed on this machine):**
- Source: `%TEMP%\xpressbus_src_backup_20261029_192240.zip`
- Database: `%TEMP%\buupasskomiuta_db_backup_20261029_195042.sql`

**Verification commands:**
```
mix precommit        # compile --warnings-as-errors, deps.unlock --unused, format, test (86/86)
MIX_ENV=dev mix ecto.migrate
```

### 2026-10-29 Session — Ticket QR codes generated locally (third-party API removed)

**Objective:** The ticket page loaded its boarding QR image from `api.qrserver.com`, leaking ticket IDs
to a third party and breaking when that service (or the user's connection) is unavailable.

**Completed:**
- Added `Xpressbus.QR` — a dependency-free QR encoder (byte mode, EC level M, versions 1–10) covering
  data encoding, Reed–Solomon over GF(256), interleaving, function patterns, mask evaluation, and
  format/version information. Public API: `QR.encode/2` (matrix), `QR.svg/2` (inline SVG, no external
  resources). `encode/2` accepts a `:mask` override for tests/diagnostics only.
- `TicketLive` now encodes the public ticket URL (`Endpoint.url() <> "/tickets?ticket_id=..."`) and
  renders an inline SVG QR in the boarding pass; falls back to printing the ticket number if encoding
  fails. No third-party image request remains.
- Added 6 tests in `test/xpressbus/qr_test.exs`, including an **exact module-for-module comparison**
  against an independent reference matrix for "helloqr" (EC M, mask 0), version selection boundaries
  (v1/v2/v3/v4/v6/v8/v10), too-long handling, finder/timing/dark-module invariants, and SVG
  self-containment.
- Independently cross-checked version 8 (49×49, multi-block interleaving + version information) against
  the same reference implementation (matrix diff: 0 modules).

**Verification:**
```
DB_PORT=3308 mix test          # 92/92 (86 existing + 6 QR)
mix compile --warnings-as-errors
```

### 2026-10-29 Session — Installable PWA (manifest, install UX, offline shell)

**Objective:** Turn the web app into a proper installable PWA instead of a bare manifest + minimal
service worker.

**Completed:**
- Enriched `priv/static/manifest.json`: app `id`, display override, portrait lock, maskable icons,
  app shortcuts (Track ticket / Book / Chyllz), categories.
- New `priv/static/offline.html` (self-contained, branded) served by the service worker on failed
  navigations; added to `XpressbusWeb.static_paths/0` so `Plug.Static` serves it.
- Rewrote `priv/static/sw.js` (`komiuta-v3`): precached offline shell + icons, stale-while-revalidate for
  digested static assets, cache-first Google Fonts, network-first navigations, `SKIP_WAITING` message
  support, and **no HTML caching** (avoids stale/personal data). Range requests and LiveView long-poll
  are bypassed.
- `assets/js/app.js`: captures `beforeinstallprompt` for the in-app install buttons, handles
  `appinstalled`, and reloads once when a new service worker takes control.
- Header (`brand_components.ex`): the existing "Download App" links (desktop + mobile) are now the PWA
  install action via a colocated `.InstallApp` hook — native install sheet where supported, "Add to Home
  Screen" hint on iOS, and the original `#app-section` download area as fallback (that section is kept
  for the future Play Store / App Store links). The links hide in standalone mode
  (`pwa-hide-installed`).
- Root layout: `mobile-web-app-capable`, `apple-mobile-web-app-title`, `application-name`, default iOS
  status bar, manifest/icons already wired.
- `assets/css/app.css`: `[hidden]` display guard (beats Tailwind utilities) and standalone
  `overscroll-behavior`/hide-installed rules.
- New `XpressbusWeb.QRCode` helper (`components/qr_code.ex`) renders safe inline SVG QR codes; the
  ticket page and the app-download section now share it.
- App-download section (`booking_live.html.heex`): the decorative QR placeholder was replaced with a
  real, locally generated QR (assigned in `BookingLive.mount/3`) that encodes the PWA URL
  (`/?source=qr_app_section`). Scanning it opens the installable web app; a caption explains that
  "Download App" then installs it. The store badges and the section are otherwise unchanged.
- 5 PWA tests in `test/xpressbus_web/pwa_test.exs`: manifest validity + icon existence + shortcuts,
  service-worker offline strategy, offline page self-containment, root-layout PWA metadata, install
  prompt wiring, and the app-download QR. Also validated `sw.js` syntax with `node --check`.
- Rebuilt Tailwind/esbuild bundles and `mix phx.digest` (offline.html included in the manifest).

**Verification:**
```
DB_PORT=3308 mix test   # 99/99 (92 + 5 PWA + 2 QR/QRCode additions)
```

### 2026-10-29 Session — Email OTP login (phone-only login blocker removed)

**Objective:** Login previously trusted a phone number with no verification, so anyone who knew a
customer's number could access that account. Replace it with email one-time codes.

**Completed:**
- New `login_codes` table (`20261029213000_create_login_codes.exs`) + `Xpressbus.Accounts.LoginCode`.
  Only an HMAC-SHA256 digest keyed with `secret_key_base` is stored; 10-minute expiry, single use,
  5 attempts, 60s resend cooldown, 5 codes/hour/account; new codes invalidate old ones.
- `Xpressbus.Accounts`: `request_login_code/1`, `resend_login_code/1`, `verify_login_code/2`,
  `get_user_by_email/1`, `find_user_for_login/1` (phone or email). `get_user/1` now resolves UUIDs
  (OTP/Google sessions) **and** legacy phone session keys.
- New `Xpressbus.LoginEmail` (branded text + HTML, code not in subject) sent through Swoosh; dev mailbox
  at `/dev/mailbox`, tests use the Swoosh Test adapter.
- `UserController`: `/user/auth` now emails a code and stores only `login_user_id`;
  new `/user/verify` (GET/POST) and `/user/verify/resend` (POST); session renewed on success
  (`configure_session(renew: true)`); user-friendly errors for expiry/lockout/cooldown/delivery failure.
- Registration now requires a valid, normalised email (`User.registration_changeset/2`), because email is
  the login factor. Login form accepts phone **or** email and links to the new verification page.
- Production mailer config: Mailgun (`MAILGUN_API_KEY` + `MAILGUN_DOMAIN`) or Resend (`RESEND_API_KEY`),
  plus `MAILER_FROM`; warns at boot when no provider is configured.
- 22 new tests (`login_code_test.exs`, `user_auth_test.exs`): delivery, expiry, single-use, attempt
  lockout, cooldown/rate limit, registration validation/normalisation, and full request→verify→session
  controller flows.

**Notes / follow-ups:**
- Legacy accounts without an email address (including synthetic `phone@xpressbus.com` guest accounts)
  cannot receive codes; an email must be set for them before they can log in.
- IP-level throttling on `/user/auth` and `/user/verify` is still recommended (per-account limits exist).

**Verification:**
```
DB_PORT=3308 mix precommit   # 121/121 tests
mix ecto.migrate             # applies the login_codes migration
```



