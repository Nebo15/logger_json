defmodule LoggerJSON.Formatter do
  @type opts :: [
          {:encoder_opts, [Jason.encode_opt()]}
          | {:metadata, :all | {:all_except, [atom()]} | [atom()]}
          | {:redactors, [{module(), term()}]}
          | {atom(), term()}
        ]

  @callback new(opts) :: {module, :logger.formatter_config()}
  @callback format(:logger.log_event(), :logger.formatter_config()) :: iodata()
end
