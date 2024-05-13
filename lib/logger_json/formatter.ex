defmodule LoggerJSON.Formatter do
  @callback format(event :: :logger.log_event(), opts :: term()) :: iodata()
end
