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

      * `:level` - log level which is used to log requests;
      * `:version_header` - request header which is used to determine API version requested by
      client, default: `x-api-version`;
      * `:metadata_formatter` - module with `build_metadata/3` function that formats the metadata
      before it's sent to logger, default - `LoggerJSON.Plug.MetadataFormatters.GoogleCloudLogger`.
      * `:extra_attributes_fn` - Function to call with `conn` to add additional
      fields to the requests. Default is `nil`.

    ### Available metadata formatters

      * `LoggerJSON.Plug.MetadataFormatters.GoogleCloudLogger` leverages GCP LogEntry format;
      * `LoggerJSON.Plug.MetadataFormatters.ELK` see module for logged structure.

    """
    @impl true
    def init(opts) do
      level = Keyword.get(opts, :log, :info)
      client_version_header = Keyword.get(opts, :version_header, "x-api-version")
      metadata_formatter = Keyword.get(opts, :metadata_formatter, MetadataFormatters.GoogleCloudLogger)

      extra_attributes_fn =
        case Keyword.get(opts, :extra_attributes_fn) do
          fun when is_function(fun) ->
            fun

          nil ->
            nil

          anything_else ->
            raise ArgumentError,
          "Incorrect input for `extra_attributes_fn`, should be one of 'function', 'nil',  got: #{inspect(anything_else)}"
        end

      {level, metadata_formatter, client_version_header, extra_attributes_fn}
    end

    @impl true
    def call(conn, {level, metadata_formatter, client_version_header, extra_attributes_fn}) do
      start = System.monotonic_time()

      Conn.register_before_send(conn, fn conn ->
        latency = System.monotonic_time() - start
        metadata = metadata_formatter.build_metadata(conn, latency, client_version_header)
        metadata = metadata ++ extra_attributes(extra_attributes_fn, conn)
        Logger.log(level, "", metadata)
        conn
      end)
    end

    @doc false
    def get_header(conn, header) do
      case Conn.get_req_header(conn, header) do
        [] -> nil
        [val | _] -> val
      end
    end

    defp extra_attributes(extra_attributes_fn, conn) do
      if extra_attributes_fn do
        extra_attributes_fn.(conn)
      else
        []
      end
    end
  end
end
