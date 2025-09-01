import Config

config :remote, :adapter, Remote.Adapters.SSH

config :remote, Remote.Adapters.SSH,
  host: System.get_env("REMOTE_HOSTNAME"),
  path: System.get_env("REMOTE_PATH")
