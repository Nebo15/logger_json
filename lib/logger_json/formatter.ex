defmodule LoggerJSON.Formatter do
  @moduledoc """
  Behaviour that should be implemented by log formatters.

  Example implementations can be found in `LoggerJSON.Formatters.GoogleCloudLogger` and
  `LoggerJSON.Formatters.BasicLogger`.
  """

  @doc """
  Initialization callback. Ran on startup with the given `formatter_opts` list.

  Returned list will be used as formatter_state in `format_event/6`.
  """
  @callback init(Keyword.t()) :: term()

  @doc """
  Format event callback.

  Returned map will be encoded to JSON.
  """
  @callback format_event(
              level :: Logger.level(),
              msg :: Logger.message(),
              ts :: Logger.Formatter.time(),
              md :: [atom] | :all,
              state :: map,
              formatter_state :: map
            ) :: map | iodata() | %Jason.Fragment{}
end
