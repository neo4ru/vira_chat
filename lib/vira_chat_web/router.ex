defmodule ViraChatWeb.Router do
  use ViraChatWeb, :router

  import ViraChatWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ViraChatWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

 scope "/", ViraChatWeb do
  pipe_through :browser

  live_session :public,
    on_mount: [{ViraChatWeb.UserAuth, :mount_current_scope}] do
    live "/", LandingLive, :index
  end
end

  if Application.compile_env(:vira_chat, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ViraChatWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", ViraChatWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [
        {ViraChatWeb.UserAuth, :mount_current_scope},
        {ViraChatWeb.UserAuth, :require_authenticated}
      ] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email

      live "/users/profile", ProfileLive, :edit
      live "/chat", ChatLive, :index
      live "/chat/:id", ChatLive, :show
    end

    live_session :admin,
  on_mount: [
    {ViraChatWeb.UserAuth, :mount_current_scope},
    {ViraChatWeb.UserAuth, :require_admin}
  ] do
  live "/admin", AdminLive.Dashboard, :index
  live "/admin/users", AdminLive.Users, :index
  live "/admin/conversations", AdminLive.Conversations, :index
  live "/admin/audit", AdminLive.Audit, :index
end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", ViraChatWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{ViraChatWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
