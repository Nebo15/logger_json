defmodule LoggerJSON.Plug do
  @moduledoc """
  A Plug to log request information in JSON format.

  It works by setting up a `Plug.Conn.register_before_send/2` callback
  which logs a structured message with `conn` and `latency` keys,
  that are handled by the formatter when the message is encoded.

  This module is not recommended to be used in production, as it can be
  costly to log every single database query.
  """
  require Logger

  @doc """
  Attaches the telemetry handler to the given event.

  ### Available options

    * `:level` - log level which is used to log requests. Defaults to `:info`.

  ### Dynamic log level

  In some cases you may wish to set the log level dynamically
  on a per-query basis. To do so, set the `:level` option to
  a tuple, `{Mod, Fun, Args}`. The query and map of time measures
  will be prepended to the provided list of arguments.

  When invoked, your function must return a
  [`Logger.level()`](`t:Logger.level()/0`) or `false` to
  disable logging for the request.

  ### Examples

  Attaching the telemetry handler to the `MyApp.Repo` events with the `:info` log level:

      LoggerJSON.Plug.attach("logger-json-queries, [:my_app, :repo, :query], :info)

  For more details on event and handler naming see
  (`Ecto.Repo` documentation)[https://hexdocs.pm/ecto/Ecto.Repo.html#module-telemetry-events].
  """
  def attach(level) do
    :telemetry.attach("logger-json", [:phoenix, :endpoint, :stop], &LoggerJSON.Plug.telemetry_logging_handler/4, level)
  end

  @doc """
  A telemetry handler that logs requests in a structured format.
  """
  @spec telemetry_logging_handler(
          event_name :: [atom()],
          query_time :: %{duration: non_neg_integer()},
          metadata :: %{conn: Plug.Conn.t()},
          level :: Logger.level() | {module :: module(), function :: atom(), arguments :: [term()]} | false
        ) :: :ok
  def telemetry_logging_handler(_event_name, %{duration: duration}, %{conn: conn}, level) do
    duration = System.convert_time_unit(duration, :native, :microsecond)

    if level = level(level, conn) do
      Logger.log(level, "", conn: conn, duration_μs: duration)
    end
  end

  defp level({m, f, a}, conn), do: apply(m, f, [conn | a])
  defp level(level, _conn) when is_atom(level), do: level
end
