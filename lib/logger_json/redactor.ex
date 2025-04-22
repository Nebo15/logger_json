defmodule LoggerJSON.Redactor do
  @moduledoc """
  This module provides a behaviour which allows to redact sensitive information from logs.

  *Note*: redactor will not be applied on `Jason.Fragment` structs if the encoder is `Jason`.
  For more information about encoding and redacting see `LoggerJSON.Formatter.RedactorEncoder.encode/2`.
  """

  @doc """
  Initializes a new redactor configuration.

  ## Compile‑time vs. Runtime Configuration

  This function can’t be used in `config.exs` because that file is evaluated
  before your application modules are compiled and loaded, so `new/1` isn’t defined yet.
  You can only call it in `config/runtime.exs` or from your application code.

  If you must set up the redactor in `config.exs`, use the tuple format:
  the first element is the module implementing `LoggerJSON.Redactor`,
  and the second is the options passed to `new/1`. For example:

    config :logger, :default_handler,
      formatter: {LoggerJSON.Formatters.Basic, redactors: [
        {MyRedactor, [option1: :value1]}
      ]}

  Note that tuple‑based configs are resolved for each log entry,
  which can increase logging overhead.
  """
  @callback new(opts :: term()) :: {module(), term()}

  @doc """
  Takes a key and a value and returns a redacted value.

  This callback will be applied on key-value pairs, like elements of structs, maps or keyword lists.
  """
  @callback redact(key :: String.t(), value :: term(), opts :: term()) :: term()

  # TODO: Make it required in a future version
  @optional_callbacks new: 1
end
