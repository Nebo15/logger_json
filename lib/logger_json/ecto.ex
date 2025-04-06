if Code.ensure_loaded?(Ecto) and Code.ensure_loaded?(:telemetry) do
  defmodule LoggerJSON.Ecto do
    @moduledoc """
    A telemetry handler that logs Ecto query metrics in JSON format.

    Please keep in mind that logging all database operations will have a performance impact
    on your application, it's not recommended to use this module in high-throughput production
    environments.
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

        LoggerJSON.Ecto.attach("logger-json-queries", [:my_app, :repo, :query], :info)

    For more details on event and handler naming see
    (`Ecto.Repo` documentation)[https://hexdocs.pm/ecto/Ecto.Repo.html#module-telemetry-events].
    """
    @spec attach(
            name :: String.t(),
            event :: [atom()],
            level ::
              Logger.level()
              | {module :: module(), function :: atom(), arguments :: [term()]}
              | false
          ) :: :ok | {:error, :already_exists}
    def attach(name, event, level) do
      :telemetry.attach(name, event, &__MODULE__.telemetry_logging_handler/4, level)
    end

    @doc """
    A telemetry handler that logs Ecto query along with it's metrics in a structured format.
    """
    @spec telemetry_logging_handler(
            event_name :: [atom()],
            measurements :: %{
              query_time: non_neg_integer(),
              queue_time: non_neg_integer(),
              decode_time: non_neg_integer(),
              total_time: non_neg_integer()
            },
            metadata :: %{required(:query) => String.t(), required(:repo) => module()},
            level ::
              Logger.level()
              | {module :: module(), function :: atom(), arguments :: [term()]}
              | false
          ) :: :ok
    def telemetry_logging_handler(_event_name, measurements, %{query: query, repo: repo}, level) do
      query_time = Map.get(measurements, :query_time) |> format_time(:nanosecond)
      queue_time = Map.get(measurements, :queue_time) |> format_time(:nanosecond)
      decode_time = Map.get(measurements, :decode_time) |> format_time(:nanosecond)
      latency = Map.get(measurements, :total_time) |> format_time(:nanosecond)

      metadata = [
        query: %{
          repo: inspect(repo),
          execution_time_us: query_time,
          decode_time_us: decode_time,
          queue_time_us: queue_time,
          latency_us: latency
        }
      ]

      if level = level(level, query, measurements) do
        Logger.log(level, query, metadata)
      else
        :ok
      end
    end

    defp level({m, f, a}, query, measurements), do: apply(m, f, [query, measurements | a])
    defp level(level, _query, _measurements) when is_atom(level), do: level

    defp format_time(nil, _unit), do: 0
    defp format_time(time, unit), do: System.convert_time_unit(time, unit, :microsecond)
  end
end
