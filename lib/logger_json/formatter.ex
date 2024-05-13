defmodule LoggerJSON.Formatter do
  @type opts :: [
          {:metadata, :all | {:all_except, [atom()]} | [atom()]}
          | {:redactors, [{module(), term()}]}
          | {atom(), term()}
        ]

  @callback format(event :: :logger.log_event(), opts :: opts()) :: iodata()
end
