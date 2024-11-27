defmodule LoggerJSON.Formatter do
  @type opts :: [
          {:encoder_opts, [Jason.encode_opt()]}
          | {:metadata, :all | {:all_except, [atom()]} | [atom()]}
          | {:redactors, [{module(), term()}]}
          | {atom(), term()}
        ]

  @callback format(event :: :logger.log_event(), config :: term) :: iodata()
end
