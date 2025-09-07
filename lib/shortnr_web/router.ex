defmodule ShortnrWeb.Router do
  use ShortnrWeb, :router

  import ShortnrWeb.AdminAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ShortnrWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_admin
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Root + unauthenticated login handled below in the auth scope

  scope "/", ShortnrWeb do
    pipe_through :api
    post "/geo", GeoController, :create
  end

  # Other scopes may use custom stacks.
  # scope "/api", ShortnrWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:shortnr, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ShortnrWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", ShortnrWeb do
    pipe_through [:browser, :redirect_if_admin_is_authenticated]

    # Disable self-registration and password reset/confirmation flows.
    # Only keep the login route.
    live_session :redirect_if_admin_is_authenticated,
      on_mount: [{ShortnrWeb.AdminAuth, :redirect_if_admin_is_authenticated}] do
      # Show login form at root when unauthenticated
      live "/", Auth.AdminLoginLive, :new
      live "/admins/log_in", Auth.AdminLoginLive, :new
      # live "/admins/register", Auth.AdminRegistrationLive, :new
      # live "/admins/reset_password", Auth.AdminForgotPasswordLive, :new
      # live "/admins/reset_password/:token", Auth.AdminResetPasswordLive, :edit
    end

    post "/admins/log_in", Auth.AdminSessionController, :create
  end

  scope "/", ShortnrWeb do
    pipe_through [:browser, :require_authenticated_admin]

    live_session :require_authenticated_admin,
      on_mount: [{ShortnrWeb.AdminAuth, :ensure_authenticated}] do
      # live "/admins/settings", Auth.AdminSettingsLive, :edit
      # live "/admins/settings/confirm_email/:token", Auth.AdminSettingsLive, :confirm_email

      # Shorten routes
      live "/shorten", Shorten.ShortenLive, :index
      live "/admins/metrics", Admin.MetricsLive, :index
      live "/admins/targets/:slug", Admin.TargetMapLive, :show
    end
  end

  scope "/", ShortnrWeb do
    pipe_through [:browser]

    delete "/admins/log_out", Auth.AdminSessionController, :delete

    live_session :current_admin,
      on_mount: [{ShortnrWeb.AdminAuth, :mount_current_admin}] do
      # live "/admins/confirm/:token", Auth.AdminConfirmationLive, :edit
      # live "/admins/confirm", Auth.AdminConfirmationInstructionsLive, :new
    end
  end

  scope "/", ShortnrWeb do
    pipe_through :browser
    get "/:slug", RedirectController, :show
  end
end
