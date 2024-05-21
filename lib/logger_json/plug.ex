if Code.ensure_loaded?(Plug) and Code.ensure_loaded?(:telemetry) do
  defmodule LoggerJSON.Plug do
    @moduledoc """
    A telemetry handler that logs request information in JSON format.

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

        # in the endpoint
        plug Plug.Telemetry, event_prefix: [:myapp, :plug]

        # in your application.ex
        LoggerJSON.Plug.attach("logger-json-requests", [:myapp, :plug, :stop], :info)

    To make plug broadcast those events see [`Plug.Telemetry`](https://hexdocs.pm/plug/Plug.Telemetry.html) documentation.

    You can also attach to the `[:phoenix, :endpoint, :stop]` event to log request latency from Phoenix endpoints:

        LoggerJSON.Plug.attach("logger-json-phoenix-requests", [:phoenix, :endpoint, :stop], :info)
    """
    def attach(name, event, level) do
      :telemetry.attach(name, event, &__MODULE__.telemetry_logging_handler/4, level)
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
        Logger.log(
          level,
          fn ->
            %{
              method: method,
              request_path: request_path,
              state: state,
              status: status
            } = conn

            [
              method,
              ?\s,
              request_path,
              ?\s,
              "[",
              connection_type(state),
              ?\s,
              status(status),
              "in ",
              duration(duration),
              "]"
            ]
          end,
          conn: conn,
          duration_μs: duration
        )
      end
    end

    defp connection_type(:set_chunked), do: "Chunked"
    defp connection_type(_), do: "Sent"

    defp status(nil), do: ""
    defp status(status), do: [status |> Plug.Conn.Status.code() |> Integer.to_string(), ?\s]

    def duration(duration) do
      if duration > 1000 do
        [duration |> div(1000) |> Integer.to_string(), "ms"]
      else
        [Integer.to_string(duration), "µs"]
      end
    end

    defp level({m, f, a}, conn), do: apply(m, f, [conn | a])
    defp level(level, _conn) when is_atom(level), do: level
  end
end
