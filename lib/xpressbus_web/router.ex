defmodule XpressbusWeb.Router do
  use XpressbusWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {XpressbusWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :auth_config do
    plug XpressbusWeb.Plugs.GoogleAuthConfig
  end

  # Per-IP abuse protection for the login-code endpoints.
  pipeline :throttle_auth do
    plug XpressbusWeb.Plugs.IpThrottle, bucket: :auth, limit: 10, window: 600
  end

  pipeline :throttle_verify do
    plug XpressbusWeb.Plugs.IpThrottle, bucket: :verify, limit: 20, window: 600
  end

  scope "/", XpressbusWeb do
    pipe_through [:browser]

    get "/sitemap.xml", SeoController, :sitemap
    live "/", BookingLive, :index
    live "/tour-packages", ChyllzLive, :index
    live "/tour-packages/insurance", InsuranceLive, :index
    live "/tour-packages/hotels", ChyllzLive, :hotels
    live "/our-packages/hidden-gems", ChyllzLive, :gems
    live "/tour-packages/car", ChyllzLive, :car
    live "/tour-packages/events", ChyllzLive, :events
    live "/buses/*route", BookingLive, :results
    live "/cities/:slug", CityLive, :show
    live "/faqs", FaqLive, :index
    live "/about", AboutLive, :index
    live "/blog", BlogLive, :index
    live "/blog/:slug", BlogLive, :show
    live "/passenger-details/:id", BookingLive, :passenger_details
    live "/review-and-pay/:id", BookingLive, :review_and_pay
    live "/tickets", TicketLive, :index
    # Printable PDF boarding pass. Authorised either by the signed token in the
    # query string (guest/post-payment flow) or by the signed-in passenger.
    get "/tickets/:ticket_id/download", UserController, :ticket_download
    live "/dashboard", UserDashboardLive, :index
    live "/payment-processing/:ticket_id", PaymentProcessingLive, :index
    live "/partner/add-fleet", PartnerRegistrationLive, :index
    live "/terms", LegalLive, :terms
    live "/privacy", LegalLive, :privacy
  end

  # Webhooks and Callbacks (Outside of browser pipeline to bypass CSRF)
  scope "/payments", XpressbusWeb do
    # Use API pipeline which has no CSRF protection
    pipe_through [:api]

    post "/mpesa/callback", PaymentController, :mpesa_callback
    post "/flutterwave/callback", PaymentController, :flutterwave_callback
    post "/flutterwave/webhook", PaymentController, :flutterwave_webhook
    get "/paystack/callback", PaymentController, :paystack_callback
    post "/paystack/webhook", PaymentController, :paystack_webhook
  end

  scope "/auth", XpressbusWeb do
    pipe_through [:browser, :auth_config]

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
    post "/:provider/callback", AuthController, :callback
  end

  scope "/user", XpressbusWeb do
    pipe_through [:browser]

    get "/login", UserController, :login
    get "/signup", UserController, :registration
    post "/register", UserController, :register
    get "/verify", UserController, :verify
    get "/complete-profile", UserController, :complete_profile
    post "/complete-profile", UserController, :save_complete_profile
    get "/tickets/:ticket_id/download", UserController, :ticket_download
    get "/logout", UserController, :logout
  end

  scope "/user", XpressbusWeb do
    pipe_through [:browser, :throttle_auth]

    post "/auth", UserController, :authenticate
  end

  scope "/user", XpressbusWeb do
    pipe_through [:browser, :throttle_verify]

    post "/verify", UserController, :confirm
    post "/verify/resend", UserController, :resend
  end

  scope "/admin", XpressbusWeb do
    pipe_through [:browser]

    get "/login", AdminController, :login
    post "/auth", AdminController, :authenticate
    get "/logout", AdminController, :logout
  end

  scope "/admin", XpressbusWeb do
    pipe_through [:browser, XpressbusWeb.Plugs.AdminAuth]

    get "/", AdminController, :dashboard_redirect
    live "/dashboard", AdminDashboardLive, :index
    live "/banners", AdminBannerLive, :index
    live "/buses", AdminFleetLive, :index
    live "/city", AdminCityLive, :index
    live "/routes", AdminRouteLive, :index
    live "/comms", AdminCommsLive, :index
    live "/bus-operators", AdminBusOperatorLive, :index
    live "/facilities", AdminFacilityLive, :index
    live "/drop-pick-points", AdminDropPickPointLive, :index
    live "/hotels", AdminHotelLive, :index
    live "/hidden-gems", AdminHiddenGemLive, :index
    live "/car-hires", AdminCarHireLive, :index
    live "/events", AdminEventLive, :index
    live "/insurance-plans", AdminInsuranceLive, :index
    live "/integration", AdminIntegrationLive, :index
    live "/coupons", AdminCouponLive, :index
    live "/users", AdminUsersLive, :index
  end

  scope "/api", XpressbusWeb do
    pipe_through :api
  end

  # Other scopes may use custom stacks.
  # scope "/api", XpressbusWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:xpressbus, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: XpressbusWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
