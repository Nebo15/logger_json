if Code.ensure_loaded?(Plug) do
  defmodule LoggerJSON.Plug.MetadataFormatters.DatadogLogger do
    @moduledoc """
    This formatter builds a metadata which is natively supported by Datadog:

      * `http` - see [DataDog](https://docs.datadoghq.com/logs/processing/attributes_naming_convention/#http-requests);
      * `phoenix.controller` - Phoenix controller that processed the request;
      * `phoenix.action` - Phoenix action that processed the request;
    """

    import Jason.Helpers, only: [json_map: 1]

    @scrubbed_keys [
      "authentication",
      "authorization",
      "confirmPassword",
      "cookie",
      "passwd",
      "password",
      "secret"
    ]
    @scrubbed_value "*********"

    @doc false
    def build_metadata(conn, latency, client_version_header) do
      client_metadata(conn, client_version_header) ++
        phoenix_metadata(conn) ++
        [
          duration: native_to_nanoseconds(latency),
          http:
            json_map(
              url: request_url(conn),
              status_code: conn.status,
              method: conn.method,
              referer: LoggerJSON.PlugUtils.get_header(conn, "referer"),
              request_headers: recursive_scrub(conn.req_headers),
              request_id: Keyword.get(Logger.metadata(), :request_id),
              request_params: recursive_scrub(conn.params),
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

    defp native_to_nanoseconds(nil) do
      nil
    end

    defp native_to_nanoseconds(native) do
      System.convert_time_unit(native, :native, :nanosecond)
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

    defp recursive_scrub(%{__struct__: Plug.Conn.Unfetched}),
      do: "%Plug.Conn.Unfetched{}"

    defp recursive_scrub([head | _tail] = data) when is_tuple(head),
      do: data |> Enum.map(&recursive_scrub/1) |> Map.new()

    defp recursive_scrub(data) when is_list(data) and length(data) > 100,
      do: "List of #{length(data)} items"

    defp recursive_scrub(data) when is_list(data),
      do: Enum.map(data, &recursive_scrub/1)

    defp recursive_scrub(data) when is_struct(data),
      do: data |> Map.from_struct() |> recursive_scrub()

    defp recursive_scrub({k, _v}) when k in @scrubbed_keys,
      do: {k, @scrubbed_value}

    defp recursive_scrub(data) when is_map(data) do
      Map.new(data, fn
        {k, _v} when k in @scrubbed_keys -> {k, @scrubbed_value}
        {k, v} -> {k, recursive_scrub(v)}
      end)
    end

    defp recursive_scrub(data), do: data
  end
end
