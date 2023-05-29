if Code.ensure_loaded?(Plug) do
  defmodule LoggerJSON.Plug.MetadataFormatters.DatadogLogger do
    @moduledoc """
    This formatter builds a metadata which is natively supported by Datadog:

      * `http` - see [DataDog](https://docs.datadoghq.com/logs/processing/attributes_naming_convention/#http-requests);
      * `phoenix.controller` - Phoenix controller that processed the request;
      * `phoenix.action` - Phoenix action that processed the request;
    """
    import Jason.Helpers, only: [json_map: 1]

    @doc false
    def build_metadata(conn, latency, client_version_header, opts \\ []) do
      unit = Keyword.get(opts, :unit, :nanosecond)

      client_metadata(conn, client_version_header) ++
        phoenix_metadata(conn) ++
        [
          duration: native_to_unit(latency, unit),
          http:
            json_map(
              url: request_url(conn),
              status_code: conn.status,
              method: conn.method,
              referer: LoggerJSON.PlugUtils.get_header(conn, "referer"),
              request_id: Keyword.get(Logger.metadata(), :request_id),
              useragent: LoggerJSON.PlugUtils.get_header(conn, "user-agent"),
              url_details:
                json_map(
                  host: conn.host,
                  port: conn.port,
                  path: conn.request_path,
                  queryString: conn.query_string,
                  scheme: conn.scheme
                )
            ),
          network: json_map(client: json_map(ip: LoggerJSON.PlugUtils.remote_ip(conn)))
        ]
    end

    defp native_to_unit(nil, _) do
      nil
    end

    defp native_to_unit(native, unit) do
      System.convert_time_unit(native, :native, unit)
    end

    defp request_url(%{request_path: "/"} = conn), do: "#{conn.scheme}://#{conn.host}/"
    defp request_url(conn), do: "#{conn.scheme}://#{Path.join(conn.host, conn.request_path)}"

    defp client_metadata(conn, client_version_header) do
      if api_version = LoggerJSON.PlugUtils.get_header(conn, client_version_header) do
        [client: json_map(api_version: api_version)]
      else
        []
      end
    end

    defp phoenix_metadata(%{private: %{phoenix_controller: controller, phoenix_action: action}} = conn) do
      [phoenix: json_map(controller: controller, action: action, route: phoenix_route(conn))]
    end

    defp phoenix_metadata(_conn) do
      []
    end

    if Code.ensure_loaded?(Phoenix.Router) do
      defp phoenix_route(%{private: %{phoenix_router: router}, method: method, request_path: path, host: host}) do
        case Phoenix.Router.route_info(router, method, path, host) do
          %{route: route} -> route
          _ -> nil
        end
      end
    end

    defp phoenix_route(_conn), do: nil
  end
end
