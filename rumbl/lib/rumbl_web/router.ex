defmodule RumblWeb.Router do
  use RumblWeb, :router

  import RumblWeb.User2Auth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {RumblWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user2
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RumblWeb do
    pipe_through :browser

    # get "/users/:id", UserController, :show

    get "/", PageController, :home
    # get "/users", UserController, :index
    # post "/users", UserController, :create
    # get "/users/:id", UserController, :show
    # get "/users/new", UserController, :new

    # Alternative way to define REST endpoints
    resources "/users", UserController, only: [:index, :show, :new, :create]
  end

  # Other scopes may use custom stacks.
  # scope "/api", RumblWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:rumbl, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RumblWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", RumblWeb do
    pipe_through [:browser, :redirect_if_user2_is_authenticated]

    get "/users2/register", User2RegistrationController, :new
    post "/users2/register", User2RegistrationController, :create
    get "/users2/log_in", User2SessionController, :new
    post "/users2/log_in", User2SessionController, :create
    get "/users2/reset_password", User2ResetPasswordController, :new
    post "/users2/reset_password", User2ResetPasswordController, :create
    get "/users2/reset_password/:token", User2ResetPasswordController, :edit
    put "/users2/reset_password/:token", User2ResetPasswordController, :update
  end

  scope "/", RumblWeb do
    pipe_through [:browser, :require_authenticated_user2]

    get "/users2/settings", User2SettingsController, :edit
    put "/users2/settings", User2SettingsController, :update
    get "/users2/settings/confirm_email/:token", User2SettingsController, :confirm_email
  end

  scope "/", RumblWeb do
    pipe_through [:browser]

    delete "/users2/log_out", User2SessionController, :delete
    get "/users2/confirm", User2ConfirmationController, :new
    post "/users2/confirm", User2ConfirmationController, :create
    get "/users2/confirm/:token", User2ConfirmationController, :edit
    post "/users2/confirm/:token", User2ConfirmationController, :update
  end
end
