defmodule LoggerJSON.Formatter do
  @type opts :: [
          {:encoder_opts, encoder_opts()}
          | {:metadata, :all | {:all_except, [atom()]} | [atom()]}
          | {:redactors, [{module(), term()}]}
          | {atom(), term()}
        ]

  @type config :: term()

  @type encoder_opts :: JSON.encoder() | [Jason.encode_opt()] | term()

  @doc """
  Initializes a new formatter configuration.

  ## Compile‑time vs. Runtime Configuration

  This function can’t be used in `config.exs` because that file is evaluated
  before your application modules are compiled and loaded, so `new/1` isn’t defined yet.
  You can only call it in `config/runtime.exs` or from your application code.

  If you must set up the formatter in `config.exs`, use the tuple format:
  the first element is the module implementing `LoggerJSON.Formatter`,
  and the second is the options passed to `new/1`. For example:

      config :logger, :default_handler,
        formatter: {LoggerJSON.Formatters.Basic, metadata: [:request_id]}

  Note that tuple‑based configs are resolved for each log entry,
  which can increase logging overhead.
  """
  @callback new(opts :: opts()) :: {module(), config()}

  @doc """
  Formats a log event.
  """
  @callback format(event :: :logger.log_event(), config_or_opts :: opts() | config()) :: iodata()

  @encoder Application.compile_env(:logger_json, :encoder, Jason)
  @encoder_protocol Application.compile_env(:logger_json, :encoder_protocol) || Module.concat(@encoder, "Encoder")
  @default_encoder_opts if(@encoder == JSON, do: &JSON.protocol_encode/2, else: [])

  @doc false
  @spec default_encoder_opts :: encoder_opts()
  def default_encoder_opts, do: @default_encoder_opts

  @doc false
  @spec encoder :: module()
  def encoder, do: @encoder

  @doc false
  @spec encoder_protocol :: module()
  def encoder_protocol, do: @encoder_protocol
end
