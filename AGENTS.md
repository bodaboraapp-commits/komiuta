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
- The admin sidebar category toggle signs (`+`/`ÃƒÆ’Ã‚Â¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢`) use circular backgrounds (`w-6 h-6 rounded-full bg-white`) with the `ml-auto` alignment to vertically align with nav_item chevrons - do not change the circle dimensions or alignment
- The Chyllz nav item in the header has no circular background, just uses colored icon (`text-[#FF4C00]` when active, `text-slate-400` when inactive)

## User Authentication

- User login page is at `/user/login` (GET) ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â accepts a **phone number or email address**
- `/user/auth` (POST) emails a **6-digit one-time code** to the account's email; it does **not** create a session yet
- `/user/verify` (GET/POST) is where the code is entered; on success the session is created with `user_id` = user UUID
- `/user/verify/resend` (POST) re-sends a code (60s cooldown, max 5 codes/hour per account)
- **Firebase SMS OTP (optional second option):** `/user/login` shows a "Sign in with SMS" panel when
  `Xpressbus.Firebase.client_config/0` is configured. The browser uses the Firebase JS SDK
  (vendored, `assets/js/firebase_phone_auth.js`) to send/confirm the SMS code; the resulting Firebase ID
  token is POSTed to `/user/firebase/verify`, checked via Google's Identity Toolkit REST API, and the
  verified phone is matched to an existing account. Config lives in `config/config.exs` under
  `:firebase` (overridable with `FIREBASE_*` env vars); admin status/check is on
  `/admin/integration ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ Firebase SMS`. Only existing accounts can use SMS login.
- **Admin login-method choice:** `/admin/integration ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ User Login` stores `integrations` provider
  `user_login` with `config.method` = `email` (default), `sms`, or `both`. The login page renders the
  selected method; if SMS is selected but Firebase is not configured, it falls back to email so users
  are not locked out. Google sign-in remains available independent of this setting.
- Codes: 6 digits, 10-minute expiry, single use, max 5 attempts, HMAC-hashed at rest (`login_codes` table)
- Registration (`/user/signup` ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ `/user/register`) now **requires a valid email address** ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â it is the login factor
- Google OAuth (`/auth/google`) remains available and signs in with the Google-verified email
- User logout is at `/user/logout` (GET)
- User dashboard is at `/dashboard`
- User dashboard tabs: `bus` ("My Bus"), `wallet` ("Wallet & Pay"), `transactions` ("History"), `referral` ("Rewards"), `profile` ("Settings"), `chyllz` ("My Chyllz")
- Default dashboard tab is `bus`
- User session uses `user_id`; OTP/Google logins store the user UUID. Legacy code paths may still store the phone number ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â `Accounts.get_user/1` resolves both
- **Legacy accounts without an email cannot receive codes** ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â set an email for those users (support/admin) before they need to log in
- In development, outgoing email is captured by the Swoosh Local adapter and visible at `/dev/mailbox`
- Production email provider: `RESEND_API_KEY` (recommended) or `MAILGUN_API_KEY` + `MAILGUN_DOMAIN` or `BREVO_API_KEY`, plus `MAILER_FROM`. **Render blocks outbound SMTP**, so mailbox/SMTP credentials cannot be used there ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â use an HTTP email API. Verify delivery with `mix komiuta.send_test_email --to you@example.com`

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

  and **Never** do this ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ the program will terminate with a syntax error:

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

### 2026-10-29 Session ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Chyllz & InSURE catalogue moved from demo content to the database

**Objective:** The Chyllz pages and the InSURE page still rendered hard-coded demo content. Make them
production pages backed by the database, with no visual regression.

**Completed:**
- Added `Xpressbus.Chyllz` ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â read-only catalogue queries (hotels, hidden gems, car hires, events) used by
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
  removed the duplicate rows created by re-running the old seeder (21ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢3 hotels, 21ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢3 gems, 21ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢3 cars,
  14ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢2 events) and `seeds.exs` is now idempotent for these tables.
- Added the read-only `/admin/insurance-plans` catalogue page and its sidebar entry; the header now keeps
  the Chyllz tab highlighted on all Chyllz sub-pages.
- Added 33 tests (catalogue context, insurance context, LiveView coverage of every public page + empty
  states, search, dialog, plan selection). Full suite: 86/86 passing.

**Important config change:** `config/test.exs` now defaults `DB_NAME` to `buupasskomiuta_test`, not the
shared development database. 5 pre-existing tests failed whenever the development database had seed data
because they assert whole-table results; `mix test` now creates and migrates the isolated test database
automatically. CI can still override `DB_NAME`.

**Content management:** to change what the public pages show, edit the catalogue rows (or
`Xpressbus.Insurance.SeedData` for launch defaults) ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â do not hard-code content in the LiveViews again.
Set a row's `active` to `false` to hide it from the public site.

**Backups (Git is not installed on this machine):**
- Source: `%TEMP%\xpressbus_src_backup_20261029_192240.zip`
- Database: `%TEMP%\buupasskomiuta_db_backup_20261029_195042.sql`

**Verification commands:**
```
mix precommit        # compile --warnings-as-errors, deps.unlock --unused, format, test (86/86)
MIX_ENV=dev mix ecto.migrate
```

### 2026-10-29 Session ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Ticket QR codes generated locally (third-party API removed)

**Objective:** The ticket page loaded its boarding QR image from `api.qrserver.com`, leaking ticket IDs
to a third party and breaking when that service (or the user's connection) is unavailable.

**Completed:**
- Added `Xpressbus.QR` ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â a dependency-free QR encoder (byte mode, EC level M, versions 1ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ10) covering
  data encoding, ReedÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œSolomon over GF(256), interleaving, function patterns, mask evaluation, and
  format/version information. Public API: `QR.encode/2` (matrix), `QR.svg/2` (inline SVG, no external
  resources). `encode/2` accepts a `:mask` override for tests/diagnostics only.
- `TicketLive` now encodes the public ticket URL (`Endpoint.url() <> "/tickets?ticket_id=..."`) and
  renders an inline SVG QR in the boarding pass; falls back to printing the ticket number if encoding
  fails. No third-party image request remains.
- Added 6 tests in `test/xpressbus/qr_test.exs`, including an **exact module-for-module comparison**
  against an independent reference matrix for "helloqr" (EC M, mask 0), version selection boundaries
  (v1/v2/v3/v4/v6/v8/v10), too-long handling, finder/timing/dark-module invariants, and SVG
  self-containment.
- Independently cross-checked version 8 (49ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â49, multi-block interleaving + version information) against
  the same reference implementation (matrix diff: 0 modules).

**Verification:**
```
DB_PORT=3308 mix test          # 92/92 (86 existing + 6 QR)
mix compile --warnings-as-errors
```

### 2026-10-29 Session ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Installable PWA (manifest, install UX, offline shell)

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
  install action via a colocated `.InstallApp` hook ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â native install sheet where supported, "Add to Home
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

### 2026-10-29 Session ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Email OTP login (phone-only login blocker removed)

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
  lockout, cooldown/rate limit, registration validation/normalisation, and full requestÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢verifyÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢session
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

### 2026-10-29 Session ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Mobile loading performance (phone payload)

**Objective:** The phone experience was slow because the landing page loaded a 637 KB hero PNG and the
Chyllz pages autoplayed a 5.9 MB video; icons came from Google's full Material Symbols font through two
render-blocking requests (one duplicated by a CSS `@import`).

**Completed:**
- Responsive hero: `hero_bg.png` is now also available as AVIF/WebP at 640/1024/1573 widths
  (**17 KB AVIF** at full width vs 637 KB PNG), rendered through `<picture>` with a matching
  `type="image/avif"` LCP preload, `fetchpriority="high"`, `decoding="async"`, and intrinsic dimensions.
  The app-download/store QR section etc. unchanged.
- Hero video is desktop-only: no `autoplay`/`<source>` in the HTML; the new `HeroVideo` hook in
  `assets/js/app.js` loads it only at `ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â°Ãƒâ€šÃ‚Â¥768px`, and skips it under Save-Data or reduced motion. Phones
  download the 16 KB WebP poster only.
- Material Symbols: removed the Google Fonts stylesheet, the `@import`, and the old preload/fallbacks.
  `scripts/fetch_icon_font.mjs` extracts the 105 used icons, downloads a **self-hosted 11 KB subset**
  (`priv/static/fonts/material-symbols-subset.woff2`), and `app.css` defines it with
  `font-display: block` + a per-glyph remote fallback. **Re-run the script when adding a new icon.**
- Below-the-fold partner/operator logos, store badges and ticket/footer logos now use
  `loading="lazy"`/`decoding="async"` with `width`/`height`; hotel room fallbacks are WebP (~16 KB each).
- Production assets rebuilt: `app.css` 111.7 KB, `app.js` 149.7 KB (minified) + `mix phx.digest`.
- 7 regression tests: `test/xpressbus_web/mobile_perf_test.exs` (source-level asset/markup guardrails) and
  `test/xpressbus_web/mobile_render_test.exs` (renders `/` and `/tour-packages` to catch stale compiled
  templates). These 13 combined mobile/PWA tests pass.

**Not changed / follow-ups:**
- Desktop still downloads the 5.9 MB hero video; re-encode it (ffmpeg) before relying on it.
- The biggest remaining phone delay is Render Free's ~1 minute cold start after idle ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â upgrade the plan
  or keep the service warm.
- `mix precommit` could not be re-run after these changes because the environment denied the required
  build-write escalation; the targeted mobile/PWA tests passed. Run `mix precommit` before deploying.

**Verification:**
```
mix assets.deploy            # minified + digested (OK)
DB_PORT=3308 mix test test/xpressbus_web/mobile_perf_test.exs test/xpressbus_web/mobile_render_test.exs test/xpressbus_web/pwa_test.exs
# 13 passed
```

### 2026-10-31 Session ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Search-result journey timeline overlap fix

**Objective:** On the bus search results card the orange bus icon overlapped the
duration/departure label above the journey line on narrow (phone) screens.

**Completed:**
- Rebuilt the results-card journey timeline (`booking_live.html.heex`): the bus icon is now an inline
  white chip between two line segments (no `absolute -top-3.5` overlay), the duration label has
  clearance above the line, and departure/arrival times are `shrink-0 whitespace-nowrap` with
  `min-w-[8px]` line segments so they cannot collapse into the icon at phone widths.
- Rebuilt Tailwind/esbuild assets (`mix assets.build`).
- Added two regression tests: source guardrail (`test/xpressbus_web/search_card_layout_test.exs`) and a
  **rendered results-page test** (`test/xpressbus_web/search_card_render_test.exs`) that seeds a bus and
  renders `/buses/nairobi-to-mombasa`.

**Verification:**
```
mix assets.build
DB_PORT=3308 mix test test/xpressbus_web/search_card_layout_test.exs test/xpressbus_web/search_card_render_test.exs
# 2 passed
```

### 2026-10-31 Session ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Login email branding (Komiuta logo)

**Objective:** The OTP email header was plain text ("Komiuta") on the orange bar; add the Komiuta logo
to the branded transaction email.

**Completed:**
- `lib/xpressbus/login_email.ex`: orange header now shows the Komiuta lockup as an image
  (`137ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â54` display, 2x asset) with `alt="Komiuta"`, plus a **"SECURE SIGN-IN"** label and a hidden
  preheader. Logo URL is absolute (`Endpoint.url() <> "/images/logo_email.png"`), with a
  `:mailer_logo_url` config override used by the local preview helper. Added
  `color-scheme`/`supported-color-schemes` meta tags for dark-mode clients.
- `priv/static/images/logo_email.png` (new): the supplied **transparent-background Komiuta logo** (190ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â52),
  displayed at 146ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â40 on a **white email header** with a thin orange brand strip. The white header keeps
  the black wordmark readable; the earlier white rounded chip was removed.
- `test/xpressbus/login_code_test.exs`: asserts the email HTML contains the absolute logo URL,
  `alt="Komiuta"`, "Secure sign-in", and that the logo PNG exists.
- `docs/komiuta-login-email-preview.png`: mockup rendered from the **actual** `LoginEmail` HTML
  (Chrome headless), using `scratch/email_preview.exs` with a `file://` logo override.

**Notes:**
- Deploy the new `logo_email.png` with the app: Gmail fetches it from
  `https://www.komiuta.com/images/logo_email.png`, so it must be publicly reachable.
- Marketing/email provider still needs `RESEND_API_KEY` (or Mailgun/Brevo) in production for delivery.

**Verification:**
```
mix compile --warnings-as-errors
DB_PORT=3308 mix test test/xpressbus/login_code_test.exs
# 15 passed
```

### 2026-10-31 Session ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Dashboard ticket modal: real QR code and Code 128 barcode

**Objective:** The "Congratulations! Booking Confirmed & E-Ticket Ready" modal on the user
dashboard drew a decorative random-pixel "QR" (`:rand.uniform/1` over a 41ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â41 grid) and a
random-width "barcode" (`Enum.random([1, 2])` px divs at 30% opacity). Neither was scannable, the
codes changed on every render, and the grid added ~1,700 DOM nodes per render.

**Completed:**
- Added `XpressbusWeb.TicketCodes` ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â the single source of truth for the boarding pass codes:
  `qr/1` renders the signed ticket URL (`Xpressbus.TicketAccess.url/1`) through the existing
  `XpressbusWeb.QRCode`/`Xpressbus.QR`, and `barcode/1,2` renders the ticket number as ISO/IEC
  15417 Code 128B through the existing `Xpressbus.Barcode`. Both return `{:safe, svg}` or `nil`.
- `Xpressbus.Barcode.svg/2` gained a `:responsive` option (`width="100%"` + `viewBox` +
  `preserveAspectRatio`) so a code can fill a fluid container while staying crisp; fixed-size
  output is unchanged, so the public ticket page is unaffected.
- `UserDashboardLive` now assigns `:ticket_qr`/`:ticket_barcode` when a ticket modal opens and
  clears them on close. The modal renders them in a 160ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â160 white QR panel (2px black border,
  4-module quiet zone from the encoder, no logo overlay covering modules) and a full-width
  white barcode strip (responsive, 56px tall, no opacity/filters). Text fallbacks remain if a
  code cannot be generated.
- `TicketLive` now uses `XpressbusWeb.TicketCodes` instead of its own duplicate `build_qr`/
  `build_barcode` helpers, so the ticket page and dashboard cannot drift apart.
- Fixed a latent crash the modal test exposed: the boarding pass read
  `@selected_ticket.bus.registration` unguarded, so any ticket without a linked `bus` row (e.g.
  seeded/legacy tickets) crashed the dashboard render. It is now nil-safe (`N/A`).
- Added 4 `TicketCodes` unit tests, 2 LiveView tests (real codes rendered in the modal, cleared on
  close) and a source guardrail test that fails if `:rand`/`Enum.random` fake codes or
  `opacity-30` return to the template.
- Visual verification: `scratch/ticket_codes_preview.exs` renders the production
  `TicketCodes` output next to the modal chrome, screenshotted with headless Chrome into
  `docs/ticket-modal-codes-preview.png` (real QR matrix + clean Code 128 bars).

**Verification:**
```
mix precommit                     # 203/203 tests
mix assets.deploy                 # rebuilt minified/digested assets
```

### 2026-10-31 Session ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Website + email contact/social details

**Objective:** Add the website, support contact details and social media links to the public footer and
to the transactional login-code email (the email previously ended with just "Komiuta ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· Elevate Your
Journey").

**Completed:**
- Added `Xpressbus.Brand` (`lib/xpressbus/brand.ex`) as the single source of truth for
  `website/0`, `website_label/0`, `email/0`, `phone/0`, `phone_uri/0` and `social_links/0`, configured in
  `config/config.exs` under `config :xpressbus, :brand`.
- Website footer (`brand_components.ex`): added the website link and a "Follow us" row with
  **Facebook / Instagram / X / TikTok** links (`target="_blank" rel="noopener noreferrer"`); email and
  phone now come from `Xpressbus.Brand`.
- Login-code email (`login_email.ex`): footer now shows
  `www.komiuta.com ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· hello@komiuta.com ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· 0800 211 211` and "Follow us: Facebook ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· Instagram ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· X ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· TikTok";
  the plain-text alternative carries the same details. Footer text is **center-aligned** in the email.
- Updated the mockup `docs/komiuta-login-email-preview.png` (rendered from the real email HTML with
  `scratch/email_preview.exs`) to show the logo, website, contact and social footer.
- Tests: `test/xpressbus_web/brand_footer_test.exs` (rendered footer + brand config consistency) and
  expanded `login_code_test.exs` assertions for the email footer.

**Important:** social URLs currently default to the `@komiuta` handles
(`facebook.com/komiuta`, `instagram.com/komiuta`, `x.com/komiuta`, `tiktok.com/@komiuta`). Confirm/replace
them in `config/config.exs` (`:brand` ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ `:social_links`) with the real pages before launch.

**Verification:**
```
mix compile --warnings-as-errors
DB_PORT=3308 mix test test/xpressbus/login_code_test.exs test/xpressbus_web/brand_footer_test.exs
# 17 passed
```

### 2026-10-31 Session ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Printable PDF boarding pass + production deploy

**Objective:** The "Download PDF" button produced a text-only A4 page with no QR/barcode, and the code
had not yet been pushed to production.

**Completed (PDF):**
- Rewrote `lib/xpressbus/ticket_pdf.ex` as a real printable boarding pass: branded orange header,
  route/date/departure/arrival/operator, passenger/seat/fare/status details, and the **same
  machine-readable codes as the on-screen pass**:
  - QR code (signed ticket URL via `Xpressbus.QR`, same payload as the dashboard/ticket page), and
  - ISO/IEC 15417 Code 128B barcode of the ticket number (`Xpressbus.Barcode`),
  - both drawn as **vector rectangles inside the PDF content stream** (no images, no new deps, crisp at
    any print resolution), with quiet zones and captions.
- Added a public, token-signed PDF route `GET /tickets/:ticket_id/download?token=...`
  (`TicketAccess.download_path/1`). `UserController.ticket_download/2` now authorises either the
  signed-in owner or a valid ticket token, so guests coming back from payment can download their PDF
  without a second login. The old `/user/tickets/:id/download` route keeps working.
- Ticket page: "DOWNLOAD PASS" (which only printed the page) is now a real **DOWNLOAD PDF** link plus a
  separate **PRINT PASS** button; dashboard modal's **Download PDF** uses the signed URL too.
- Verified the rendered PDF visually (`docs/ticket-boarding-pass-preview.pdf` + `.png`) ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â real QR matrix
  and clean Code 128 bars; added tests for the vector codes, PDF xref integrity, token/owner/guest
  authorisation, and the download links.

**Completed (deploy):**
- Ran `mix precommit` ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ **213/213**.
- Committed the working tree (`22850b7`) and pushed branch `phoenix-app` to
  `github.com/bodaboraapp-commits/komiuta` using the portable MinGit in `%TEMP%\komiuta-git` over the
  machine's GitHub SSH key (no token file needed; `GIT_SSH=C:\Windows\System32\OpenSSH\ssh.exe`).
- Render auto-deployed on the push. Verified against the live site: `/` (hero `<picture>` AVIF),
  `/user/login` (OTP copy), `/tour-packages` + `/tour-packages/hotels` (search + DB cards),
  `/tour-packages/insurance` (DB plan grid + coverage table), `/admin/insurance-plans` ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ login redirect,
  `/tickets/:id/download` ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ new route. `scratch/smoke-test.ps1 -BaseUrl https://www.komiuta.com`:
  **all checks passed**.
- `login.html.heex`: copy now says "Phone or Email" with an email-or-phone placeholder (backend already
  accepted both).
- Note: the Render API key in `%TEMP%\render-api-key.txt` returns an empty service list (stale/other
  account), so deployment status is verified through the live site and the GitHub push instead.

**Follow-ups for go-live (operational, see PRODUCTION_READINESS.md):** configure `RESEND_API_KEY`
(OTP email delivery), production payment integration secrets/callbacks, strong admin credentials and a
DB backup/plan decision.

**Verification:**
```
mix precommit                 # 213/213 tests
git push origin phoenix-app   # 8928f7f..22850b7 (+ follow-up commit)
.\scratch\smoke-test.ps1 -BaseUrl https://www.komiuta.com   # all PASS
```

### 2026-11-06 Session ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Clear stale pending bookings (local DB done, production on next deploy)

**Objective:** Abandoned "pending" ticket bookings made before 2026-11-06 were cluttering the app. Clear
them (and their payment attempts) from the local development database and production.

**Local database (`buupasskomiuta_db`, done manually with backups):**
- Deleted **8 pending tickets** (created 21ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ24 Sep 2026) and their **8 linked payments** (6 pending,
  2 failed M-PESA attempts) in a transaction. Confirmed bookings were untouched.
- Backups written before deletion to
  `backups/db-cleanup-20261106/` (workspace; not committed):
  `buupasskomiuta_db_full.sql` (full dump), `pending_tickets_before_today.sql` (the 8 ticket rows),
  `linked_payments.sql` (the 8 payment rows).
- Started the local XAMPP MariaDB (`mysqld --defaults-file=C:\xampp\mysql\bin\my.ini --standalone`) ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
  it was not running after the last reboot.

**Production (via code + git push, because Aiven credentials/valid Render API key are not available):**
- Added `Xpressbus.DataCleanup` (`lib/xpressbus/data_cleanup.ex`): archives rows as JSON into the new
  `pending_booking_archive` table (migration `20261106094000_create_pending_booking_archive.exs`) and
  then deletes pending tickets created before a cutoff plus their linked payments ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â inside one
  transaction. Safety rules: never touches bookings created after the cutoff; keeps any pending ticket
  that has a `success` payment (paid-but-pending anomalies are reported, not deleted); idempotent;
  schema-decoupled (schemaless queries) so it works regardless of pending schema migrations.
- Added the Mix task `mix komiuta.clear_pending_bookings [--before YYYY-MM-DD] [--dry-run]`
  (`lib/mix/tasks/komiuta.clear_pending_bookings.ex`; default cutoff = 00:00 Africa/Nairobi today).
- `priv/repo/render_bootstrap.exs` now runs the cleanup once per boot with the fixed cutoff
  `2026-11-05T21:00:00Z` (= 2026-11-06 00:00 Africa/Nairobi), logs the counts, and is wrapped in a
  rescue so a data problem can never block boot. Render's start command runs the bootstrap after
  `mix ecto.migrate`, so the next deploy performs the cleanup automatically and keeps the archived rows
  in `pending_booking_archive` for recovery.
- Tests: `test/xpressbus/data_cleanup_test.exs` (dry run, archive+delete scope, idempotency,
  paid-but-pending protection, cutoff conversion).

**Verification (local):**
```
MIX_ENV=dev mix ecto.migrate
mix komiuta.clear_pending_bookings --before 2026-11-06 --dry-run   # 0 tickets / 0 payments after cleanup
mix run priv/repo/render_bootstrap.exs                             # cleanup no-op, boot OK
```

### 2026-11-06 Session ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â "+ Add Return" button on the bus search pill

**Objective:** Let users turn the landing bus search into a round trip from the search pill itself
(there was a return-date plumbing in the LiveView, but no way to add one and the old default silently
marked every booking as "Round Trip").

**Completed:**
- `BookingLive` now has explicit `:return_added` / `:return_date` state. The always-set
  `departure + 28 days` default is gone: one-way searches keep `return_date = nil`, so the recorded
  ticket `type` is "One Way" instead of always "Round Trip".
- Search pill (`booking_live.html.heex`): after the Travel Date field there is now an
  **"+ Add Return"** outline chip (`#add-return-button`). Clicking it reveals a **Return Date** field
  (`#return-date-field`, `#search-return-date`) with a remove (`ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â`, `#remove-return-button`) control.
  Layout is responsive: chip on desktop, full-width row on phones; no horizontal overflow and the
  fixed hero (`pb-[200px]`) settings are untouched.
- Round trips are carried through the results URL (`return=YYYY-MM-DD`), the results summary shows a
  **Return date** badge (`#round-trip-badge`), the passenger page title shows `round trip ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· return
  <date>`, and the payment/ticket `type` becomes "Round Trip".
- Return date validation/normalisation: the return date can never be before the travel date (it is
  bumped to travel + 7 days if the travel date moves past it), and an invalid/missing value falls back
  to travel + 7 days.
- **MODIFY** on the results page now returns to the landing pill with from/to/date/return prefilled
  (`#modify-search-button`), and `/?from=...&to=...&date=...&return_date=...` deep links prefill the
  pill (`prefill_search_from_params/2`).
- Tests: `test/xpressbus_web/search_return_trip_test.exs` (8 tests: add/remove field, default
  return date, round-trip URL, one-way URL without `return`, results badge, MODIFY state, deep-link
  prefill).
- Visual check: `scratch/return_trip_screenshot.js` (puppeteer-core + installed Chrome) captured the
  pill in one-way/round-trip state on desktop 1440px and mobile 390px ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â both fit within the viewport
  (`docScrollWidth == innerWidth`) and the results page renders the return badge.

**Not implemented:** the return leg is still booked as a separate one-way search; the round-trip
selection records the intent/return date (ticket type + UI) but does not purchase both legs in one
payment. A two-leg checkout would need a multi-bus booking model.

**Verification:**
```
mix precommit        # 267/267 tests
mix assets.build     # rebuilt Tailwind/esbuild bundles
node scratch/return_trip_screenshot.js   # desktop + mobile screenshots, no overflow
```

### 2026-11-06 Session ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Database-driven "recent booking" pills above the trusted-partner marquee

**Objective:** Show a live/tending booking strip on the landing page, directly above the trusted
partner logos and outside the search pill, without exceeding the search section's width.

**Completed:**
- New read-only context `Xpressbus.Trending` (`lib/xpressbus/trending.ex`):
  - **Live mode:** confirmed tickets from the last 7 days, grouped by `from`/`to`, ordered by booking
    count then recency (up to 8 pills).
  - **Popular fallback:** when nothing was booked in the live window, the all-time most booked routes
    are shown instead (labelled "Popular routes" rather than "Live bookings").
  - Privacy: only route, count and latest-booking time are selected ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â no passenger/phone/ticket/price
    data ever leaves the DB. `relative_time/1` renders "just now", "4m ago", "3h ago", "2d ago".
- `BookingLive` fetches the pills in parallel with the existing mount queries, assigns
  `:recent_booking_pills` / `:recent_booking_mode`, and refreshes them every 60s while the landing page
  is open (`:refresh_trending_bookings`) so the row behaves like a live feed.
- Landing template (`booking_live.html.heex`): new `#recent-bookings-pills` row rendered **after the
  hero/search pill and before the trusted-operators section**. It uses the same
  `max-w-[1350px] mx-auto px-6` width budget as the search pill, with `overflow-x-auto no-scrollbar`
  so extra pills scroll horizontally instead of widening the page. Pills are compact rounded chips with
  a live (emerald) or popular (white) style and a pulsing dot; the row is hidden entirely when there are
  no confirmed bookings.
- Clearance below the absolutely-positioned search pill is handled by explicit CSS
  (`#recent-bookings-pills` padding-top `7rem` on phones / `3.5rem` from 768px) in `assets/css/app.css`,
  because the stacked mobile pill overhangs the hero further than the desktop pill.
- Tests: `test/xpressbus/trending_test.exs` (live ordering/counts, pending & old bookings excluded,
  popular fallback, limit, relative time) and `test/xpressbus_web/recent_bookings_pills_test.exs`
  (row rendered before partners, correct live label/routes, width classes/scroll container, hidden
  when no bookings).

**Verification:**
```
mix precommit        # 274/274 tests
mix assets.build
node scratch/recent_bookings_screenshot.js   # desktop 1440 / mobile 390: row within search-pill width, no overlap, no overflow
```

### 2026-11-06 Session ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Two-hour departure window sanitizer for bus search

**Objective:** Search results were showing buses departing within minutes/two hours ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â trips a user cannot
realistically catch (and can leave them paying for a bus that has already left). Hide those from the
search.

**Completed:**
- New `Xpressbus.Bookings.DepartureWindow` (`lib/xpressbus/bookings/departure_window.ex`):
  - hides buses whose departure on the searched travel date is **less than 2 hours from now** (Kenya
    time, EAT UTC+3) or already in the past;
  - parses `"7:00 AM"`, `"7:00am"`, `"07:30"` (24h), `"7 PM"` and rejects unparseable/blank times (hidden
    rather than shown unverified);
  - `:now` can be injected for deterministic tests; `now_eat/0` and `min_lead_time_hours/0` are public.
- New `Xpressbus.Bookings.Search` (`lib/xpressbus/bookings/search.ex`): the DB search query moved out of
  the LiveView, keeping the existing hygiene filters (no `legacy_fallback`, no `0 seats left`, approved
  operators only) and applying `DepartureWindow.filter_bookable/3` to the results.
- `BookingLive` now uses `Search.list_bookable/3` for database results **and** runs the same sanitizer on
  the async scraper (`BuuPass`) results in `handle_async(:bus_search, ...)`, so live results cannot leak
  a soon-departing trip either. Removed the now-unused `import Ecto.Query` from the LiveView.
- Tests: `test/xpressbus/bookings/departure_window_test.exs` (2h boundary, past departures, 24h/compact
  formats, unparseable times hidden, future dates unaffected, field preservation, parser cases) and
  `test/xpressbus/bookings/search_test.exs` (window applied on DB search, hygiene filters preserved,
  future date unaffected, invalid date, route isolation). `search_card_render_test.exs` fixture now uses
  a dynamic departure outside the window so it keeps testing the results card rendering.

**Verification:**
```
mix precommit        # 286/286 tests
```

### 2026-11-06 Session ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â One consistent search API across every public bus surface

**Objective:** Make sure the public bus-visibility rules are identical everywhere a bus can appear ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
booking search, the BuuPass cache fallback, city pages, operator pages and SEO route discovery ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â and
prove it with tests.

**Completed:**
- `Xpressbus.Bookings.Search` is now the single source of truth:
  - `base_query/0` = public visibility (no `legacy_fallback`, no sold-out `"0 seats left"` ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â nil seat
    text allowed, and only buses whose partner operator is approved or absent);
  - `list_bookable/4` = base query + route/date + 2-hour `DepartureWindow` filter (search results);
  - `list_route_inventory/3` = base query + route/date without the time window (summary/SEO only).
- **Removed the duplicate search implementations:**
  - `Xpressbus.Bookings.Scraper.list_from_db/3` (a second SQL query without the operator-approval
    filter) is gone; `Scraper.search/4` now reads the cache through `Search.list_bookable/4`, so the
    live BuuPass path and the DB path return exactly the same rows.
  - The scraper's private two-hour filter was duplicated (`filter_soon_departures/2`); it now delegates
    to `DepartureWindow` (kept as a `@doc false` compatibility helper) and judges each bus against its
    own travel date.
- Every other public surface now composes `Search.base_query/0` instead of its own copy of the filters:
  - `XpressbusWeb.CityLive.routes_from_city/1` (city landing pages),
  - `XpressbusWeb.Operators.top/1`, `routes/1`, `cities/1` (operator pages/sitemap),
  - `XpressbusWeb.SeoController.sitemap/2` route discovery.
  Admin screens (`Xpressbus.Buses`) still query all rows directly, intentionally.
- Tests: new `test/xpressbus_web/search_consistency_test.exs` seeds approved/unapproved/legacy/sold-out
  buses and asserts the booking results page, `Search.list_bookable`, `Scraper.search`, city pages,
  operator pages and the sitemap all show/hide the same buses. `scraper_test.exs` now asserts
  `Search.list_bookable` and `Scraper.search` return identical IDs.

**Verification:**
```
mix precommit        # 315/315 tests
```

### 2026-11-06 Session ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Admin sidebar: User List and Agent List split

**Objective:** The admin sidebar had a single combined "User/Agent List" entry (pointing at the users
page) plus a separate "Agent Applications" entry. Split the combined label into two clearly separate
lists in the admin nav.

**Completed:**
- `lib/xpressbus_web/components/admin_components.ex` sidebar now has two adjacent entries:
  - **User List** ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â `group` icon, `id="users"`, links to `/admin/users`;
  - **Agent List** ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â `support_agent` icon, `id="agents"`, links to `/admin/agent-applications`.
  The combined "User/Agent List" label and the separate "Agent Applications" nav entry are gone; the
  tests/refunds entry follows the two list entries.
- `AdminUsersLive`: page title and page header renamed from "User/Agent List" to **User List** (nav
  label and page header now match).
- Tests: `test/xpressbus_web/admin_users_live_test.exs` updated for the new label plus a new test that
  asserts the sidebar renders separate `User List` + `Agent List` links (`/admin/users` and
  `/admin/agent-applications`) on both admin pages and no longer contains "User/Agent List".

**Verification:**
```
mix precommit        # 318/318 tests
```

### 2026-11-06 Session ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Tickets & Refunds moved into the BUS section as split items

**Objective:** The combined "Tickets & Refunds" admin entry lived in the Settings section. Move it to the
BUS section and split it into **Tickets** and **Refunds** as separate list items.

**Completed:**
- Admin sidebar (`lib/xpressbus_web/components/admin_components.ex`):
  - BUS section now ends with **Tickets** (`confirmation_number` icon ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ `/admin/tickets`, `id="tickets"`)
    and **Refunds** (`reply` icon ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ `/admin/refunds`, `id="refunds"`), right after Facility.
  - The combined "Tickets & Refunds" entry was removed from the Settings section.
- New refunds admin page:
  - `Xpressbus.Tickets.paginate_refunds/3` joins `ticket_refunds` with `tickets` (passenger, route, price)
    and supports search by ticket id, refund reference, passenger name or phone.
  - `Xpressbus.Tickets.refund_totals/0` returns the refund count and total refunded amount.
  - `AdminRefundsLive` + template (`/admin/refunds`): totals cards, searchable/paginated refund table with
    amount, reference, email/SMS notification badges and status.
- `AdminTicketsLive`: page title and header renamed from "Tickets & Refunds" to **Tickets** (refunds now
  have their own page).
- Tests: `test/xpressbus_web/live/admin_refunds_live_test.exs` (redirect, list + totals, search, empty
  state, split nav entries). Existing tickets/admin tests still pass.

**Verification:**
```
mix precommit        # 334/334 tests
```

### 2026-11-06 Session ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Distinct PWA colours: KOMIUTA orange, KOMIUTA Agent white

**Objective:** The main KOMIUTA PWA and the KOMIUTA Agent PWA both looked the same once installed
(white-background icons + white splash). Make one white and the other brand red/orange so they are easy
to tell apart on a home screen.

**Completed:**
- **KOMIUTA (main app)** is now the orange one:
  - `priv/static/images/app-icon-180/192/512.png`, `app-icon-maskable-512.png` and
    `apple-touch-icon.png` regenerated as **white Komiuta lockup on a #FF4C00 background** (maskable
    variant keeps the logo inside the 80% safe zone).
  - `priv/static/manifest.json`: `background_color` changed from `#ffffff` to `#FF4C00` (theme was
    already `#FF4C00`), so the installed splash screen is orange too.
- **KOMIUTA Agent** stays the white one: `agent-manifest.json` keeps `theme_color`/`background_color`
  `#ffffff` with the white-background `agent-icon-*` artwork; `AgentLive` and `AgentSessionController`
  already pin `page_theme_color: "#ffffff"`, `page_manifest: "/agent-manifest.json"` and
  `page_apple_touch_icon: "/images/agent-icon-180.png"`.
- Tests: `test/xpressbus_web/pwa_test.exs` updated for the orange main manifest and a new test asserting
  the two manifests have distinct themes (`#FF4C00` vs `#ffffff`), distinct icon artwork, valid agent
  icons, and agent-source metadata pinning the white identity.
- Icon generator: `scratch/generate_orange_icons.py` (Pillow) derives the white lockup from the alpha
  channel of `logo_brand.png` and composites it on the brand orange.

**Verification:**
```
mix precommit        # 349/349 tests
```

### 2026-11-06 Session Ã¢â‚¬â€ Cleaner agent-application cards on the admin Agent List

**Objective:** The Agent Applications page crammed identity, contact details, reference and the
approve / reject controls into a single cramped row block. Rework each application into a properly
structured card without changing the underlying actions.

**Completed (`lib/xpressbus_web/live/admin_agent_applications_live.html.heex`):**
- Each application is now an `<article id="application-<id>">` card with three zones:
  - **Header:** storefront tile, business name + status pill with colour dot, contact rows with icons
    (`person` / `location_on` / `call` / `mail` / `payments`), tappable `tel:`/`mailto:` links, and a
    right-aligned reference chip + **Submitted <date>** stamp.
  - **Details grid (only when present):** Routes, Agent note, Admin note and Reviewed date as labelled
    tiles (amber styling for the admin/rejection note).
  - **Action bar:** `Approve` (solid emerald with check icon), `Pending` (outline with schedule icon) and
    an inline rejection form with an explicit Ã¢â‚¬Å“Rejection reason (sent to agent)Ã¢â‚¬Â label, placeholder and
    a compact red **Reject** button.
- Payout label now renders **M-Pesa** (was Ã¢â‚¬Å“MpesaÃ¢â‚¬Â) via a `payout_label/1` helper in
  `AdminAgentApplicationsLive` (also Bank / Card), and the rejection textarea/button stack full-width on
  phones while staying inline on desktop.
- Tests: `test/xpressbus_web/live/admin_agent_applications_live_test.exs` extended with the card id,
  `tel:`/`mailto:` links, Ã¢â‚¬Å“Payout: M-PesaÃ¢â‚¬Â, Ã¢â‚¬Å“SubmittedÃ¢â‚¬Â, and a new test asserting routes, agent note,
  admin note and reviewed date render.

**Verification:**
```
mix precommit        # 355/355 tests
node scratch/agent_applications_screenshot.js   # desktop 1440 + phone 390, no horizontal overflow
```

### 2026-11-06 Session â€” Collapsible agent-application cards with a submission/review timeline

**Objective:** The expanded application card took a lot of vertical space in the Agent List, and the
reference / submitted / reviewed dates were scattered. Compact the list and put that history on a
timeline.

**Completed:**
- Cards now render **collapsed by default** (~97px tall): storefront tile, business name + status pill,
  compact contact line (name, city, email), reference + submitted date on the right, and a rotating
  `expand_more` chevron. Clicking the summary row toggles the expansion via the `toggle_application`
  LiveView event (`expanded_applications` MapSet, `aria-expanded` kept in sync).
- The expanded panel (details and action bar) only renders while open and contains:
  - a **Contact** tile (tap-to-call / tap-to-email / payout), **Routes** and **Agent note** tiles,
  - an **Activity timeline** showing **Application submitted** (date + `Ref AGT-â€¦` chip) followed by the
    review node (**Application approved** / **Application rejected**, with its date/time, or
    *Awaiting review* for pending applications), colour-coded dots with a connecting line,
  - the Approve / Pending buttons and the rejection-reason form.
- Layout: details and the Activity timeline sit side-by-side on desktop (`lg:flex-row`, timeline
  fixed `lg:w-72`) and stack on phones; no horizontal overflow at 390px. The existing form id
  (`#reject-agent-<id>`), `update_status` / `reject_application` events and test selectors still work.
- Tests: `admin_agent_applications_live_test.exs` updated so approve/reject first expand the card,
  plus assertions for the collapsed state (no `#application-details-<id>`), expansion/collapse toggle,
  timeline text (`Application submitted`, `Ref â€¦`, `Application rejected`) and the `tel:`/`mailto:` links.

**Verification:**
```
mix precommit        # 362/362 tests
node scratch/agent_applications_screenshot.js   # collapsed 97px, expanded timeline; desktop + phone 390, no overflow
```

### 2026-11-06 Session — Fix legacy Agent PWA installs not launching

**Objective:** Agent PWA installs created before the Agent app moved to `agent.komiuta.com` opened as a
blank/loading screen on Android. Their installed `start_url` is `www.komiuta.com/agent`; the website
answered that with a 302 to the Agent subdomain, and a cross-origin redirect while Chrome launches a
standalone PWA makes Android fall back to the browser (or an empty window).

**Completed:**
- `XpressbusWeb.Plugs.AgentHost` no longer redirects `www.komiuta.com/agent` to the Agent subdomain.
  The legacy `/agent` page is served normally so an already-installed Agent PWA launches in standalone
  mode on the website origin and can use its existing www session. The Agent subdomain root
  (`agent.komiuta.com/`) still redirects to `/agent`.
- `assets/js/app.js` now redirects **normal browser visits** (non-standalone display mode) to
  `https://agent.komiuta.com` for `/agent*` paths on the website hosts, so new users still install the
  Agent app from its own origin (no nested PWA scopes). Installed PWA launches
  (`display-mode: standalone` / `navigator.standalone`) stay on the website page they were installed
  from, fixing the legacy blank/redirect launch.
- `priv/static/sw.js` cache version bumped `komiuta-v5` so old installs activate a fresh service worker
  and drop stale shell/asset caches from before the subdomain split.
- Tests: `agent_pwa_test.exs` website-`/agent` test now asserts the page renders with the Agent manifest
  and that `app.js` contains the standalone-aware client redirect; the Agent subdomain redirect test is
  unchanged.

**Verification:**
```
mix test test/xpressbus_web/agent_pwa_test.exs   # passes
mix precommit                                   # full suite
```

























