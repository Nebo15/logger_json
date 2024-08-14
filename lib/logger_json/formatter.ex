defmodule LoggerJSON.Formatter do
  @type opts :: [
          {:encoder_opts, term}
          | {:metadata, :all | {:all_except, [atom()]} | [atom()]}
          | {:redactors, [{module(), term()}]}
          | {atom(), term()}
        ]

  @callback format(event :: :logger.log_event(), opts :: opts()) :: iodata()
end
