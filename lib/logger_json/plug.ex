if Code.ensure_loaded?(Plug) do
  defmodule LoggerJSON.Plug do
    @moduledoc """
    A Plug to log request information in JSON format.
    """
    alias Plug.Conn
    alias LoggerJSON.Plug.MetadataFormatters
    require Logger

    @behaviour Plug

    @doc """
    Initializes the Plug.

    ### Available options

      * `:log` - log level which is used to log requests;
      * `:version_header` - request header which is used to determine API version requested by
      client, default: `x-api-version`;
      * `:metadata_formatter` - module with `build_metadata/3` function that formats the metadata
      before it's sent to logger, default - `LoggerJSON.Plug.MetadataFormatters.GoogleCloudLogger`.

    ### Available metadata formatters

      * `LoggerJSON.Plug.MetadataFormatters.DatadogLogger` see module for logged structure;
      * `LoggerJSON.Plug.MetadataFormatters.GoogleCloudLogger` leverages GCP LogEntry format;
      * `LoggerJSON.Plug.MetadataFormatters.ELK` see module for logged structure.

    ### Dynamic log level
        
        In some cases you may wish to set the log level dynamically
        on a per-request basis. To do so, set the `:log` option to
        a tuple, `{Mod, Fun, Args}`. The `Plug.Conn.t()` for the
        request will be prepended to the provided list of arguments.
        
        When invoked, your function must return a
        [`Logger.level()`](`t:Logger.level()/0`) or `false` to
        disable logging for the request.
        
        For example, in your Endpoint you might do something like this:
        
              # lib/my_app_web/endpoint.ex
              plug LoggerJSON.Plug,
                log: {__MODULE__, :log_level, []}
        
              # Disables logging for routes like /status/*
              def log_level(%{path_info: ["status" | _]}), do: false
              def log_level(_), do: :info

    """
    @impl true
    def init(opts) do
      level = Keyword.get(opts, :log, :info)
      client_version_header = Keyword.get(opts, :version_header, "x-api-version")
      metadata_formatter = Keyword.get(opts, :metadata_formatter, MetadataFormatters.GoogleCloudLogger)
      {level, metadata_formatter, client_version_header}
    end

    @impl true
    def call(conn, {level, metadata_formatter, client_version_header}) do
      start = System.monotonic_time()
      computed_level = level(level, conn)

      if computed_level do
        Conn.register_before_send(conn, fn conn ->
          latency = System.monotonic_time() - start
          metadata = metadata_formatter.build_metadata(conn, latency, client_version_header)
          Logger.log(computed_level, "", metadata)
          conn
        end)
      else
        conn
      end
    end

    defp level(level, _conn) when is_atom(level), do: level

    defp level({mod, func, args}, conn) do
      apply(mod, func, [conn | args])
    end
  end
end
