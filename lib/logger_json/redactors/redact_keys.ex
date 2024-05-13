defmodule LoggerJSON.Redactors.RedactKeys do
  @moduledoc """
  A simple redactor which replace the value of the keys with `"[REDACTED]"`.

  It takes list of keys to redact as an argument, eg.:
  ```elixir
  config :logger, :default_handler,
    formatter: {LoggerJSON.Formatters.Basic, redactors: [
      {LoggerJSON.Redactors.RedactKeys, ["password"]}
    ]}
  ```

  Keep in mind that LoggerJSON will convert key type to string before comparing it
  with the list of keys to redact.
  """

  @behaviour LoggerJSON.Redactor

  def redact(key, value, keys) do
    if key in keys do
      "[REDACTED]"
    else
      value
    end
  end
end
