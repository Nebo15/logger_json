defmodule LoggerJSON.Phoenix.Logger do
  require Logger
  import Phoenix.Logger, only: [duration: 1]

  @default_opts [
    version_header: "x-api-version",
    metadata_formatter: LoggerJSON.Plug.MetadataFormatters.GoogleCloudLogger,
    duration_unit: :nanosecond
  ]

  @spec install(opts :: list()) :: any()
  def install(opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    handlers = %{
      [:phoenix, :endpoint, :stop] => &__MODULE__.phoenix_endpoint_stop/4
    }

    for {key, fun} <- handlers do
      :telemetry.attach({__MODULE__, key}, key, fun, opts)
    end
  end

  def phoenix_endpoint_stop(_event, %{duration: duration}, %{conn: conn} = metadata, config) do
    case log_level(metadata[:options][:log], conn) do
      false ->
        :ok

      level ->
        version_header = Keyword.get(config, :version_header)
        metadata_formatter = Keyword.get(config, :metadata_formatter)
        unit = Keyword.get(config, :duration_unit)
        metadata = metadata_formatter.build_metadata(conn, duration, version_header, unit: unit)

        Logger.log(
          level,
          fn ->
            %{status: status, method: method} = conn
            status_str = Integer.to_string(status)
            [method, " ", conn.request_path, " returns ", status_str, " in ", duration(duration)]
          end,
          metadata
        )
    end
  end

  defp log_level(nil, _conn), do: :info
  defp log_level(level, _conn) when is_atom(level), do: level

  defp log_level({mod, fun, args}, conn) when is_atom(mod) and is_atom(fun) and is_list(args) do
    apply(mod, fun, [conn | args])
  end
end
