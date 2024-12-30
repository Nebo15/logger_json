import Config

encoder =
  if Version.compare(System.version(), "1.18.0") == :lt do
    Jason
  else
    JSON
  end

config :logger_json, encoder: encoder

config :logger,
  handle_otp_reports: true,
  handle_sasl_reports: false
