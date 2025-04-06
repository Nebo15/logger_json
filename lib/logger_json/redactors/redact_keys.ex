defmodule LoggerJSON.Redactors.RedactKeys do
  @moduledoc """
  A simple redactor which replace the value of the keys with `"[REDACTED]"`.

  It takes list of keys to redact as an argument, eg.:
  ```elixir
  config :logger, :default_handler,
    formatter:
      LoggerJSON.Formatters.Basic.new(
        redactors: [
          LoggerJSON.Redactors.RedactKeys.new(["password"])
        ]
      )
  ```

  Keep in mind that the key will be converted to binary before sending it to the redactor.
  """

  @behaviour LoggerJSON.Redactor

  @impl LoggerJSON.Redactor
  def new(keys) do
    {__MODULE__, keys}
  end

  @impl LoggerJSON.Redactor
  def redact(key, value, keys) do
    if key in keys do
      "[REDACTED]"
    else
      value
    end
  end
end
