import Config

config :logger, backends: [LoggerJSON]
config :logger_json, :backend, json_encoder: Jason
