# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :vira_chat, :scopes,
  user: [
    default: true,
    module: ViraChat.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: ViraChat.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :vira_chat,
  ecto_repos: [ViraChat.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :vira_chat, ViraChatWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ViraChatWeb.ErrorHTML, json: ViraChatWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ViraChat.PubSub,
  live_view: [signing_salt: "vk6fkI0W"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :vira_chat, ViraChat.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  vira_chat: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  vira_chat: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

# Web push notifications. The VAPID key pair is configured per environment
# (config/dev.exs for development, VAPID_* environment variables in production).
# Without a key pair, push notifications are skipped.
config :web_push_elixir, vapid_subject: "mailto:admin@virachat.local"
