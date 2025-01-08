defmodule LoggerJSON.Formatters.Datadog do
  @moduledoc """
  Custom Erlang's [`:logger` formatter](https://www.erlang.org/doc/apps/kernel/logger_chapter.html#formatters) which
  writes logs in a structured format that can be consumed by Datadog.

  This formatter adheres to the
  [default standard attribute list](https://docs.datadoghq.com/logs/processing/attributes_naming_convention/#default-standard-attribute-list)
  as much as possible.

  ## Formatter Configuration

  The formatter can be configured with the following options:

  * `:hostname` (optional) - changes how the `syslog.hostname` is set in logs. By default, it uses `:system` which uses
    `:inet.gethostname/0` to resolve the value. If you are running in an environment where the hostname is not correct,
    you can hard code it by setting `hostname` to a string. In places where the hostname is inaccurate but also dynamic
    (like Kubernetes), you can set `hostname` to `:unset` to exclude it entirely. You'll then be relying on
    [`dd-agent`](https://docs.datadoghq.com/agent/) to determine the hostname.

  For list of shared options see "Shared options" in `LoggerJSON`.

  ## Metadata

  For list of other well-known metadata keys see "Metadata" in `LoggerJSON`.

  ## Examples

      %{
        "domain" => ["elixir"],
        "logger" => %{
          "file_name" => "/Users/andrew/Projects/os/logger_json/test/formatters/datadog_test.exs",
          "line" => 44,
          "method_name" => "Elixir.LoggerJSON.Formatters.DatadogTest.test logs an LogEntry of a given level/1",
          "thread_name" => "#PID<0.234.0>"
        },
        "message" => "Hello",
        "syslog" => %{
          "hostname" => "MacBook-Pro",
          "severity" => "notice",
          "timestamp" => "2024-04-11T23:03:39.726Z"
        }
      }
  """
  import LoggerJSON.Formatter.{MapBuilder, DateTime, Message, Metadata, Code, RedactorEncoder}
  require LoggerJSON.Formatter, as: Formatter

  @behaviour Formatter

  @encoder Formatter.encoder()

  @processed_metadata_keys ~w[pid file line mfa conn]a

  @impl Formatter
  def format(%{level: level, meta: meta, msg: msg}, opts) do
    opts = Keyword.new(opts)
    encoder_opts = Keyword.get_lazy(opts, :encoder_opts, &Formatter.default_encoder_opts/0)
    redactors = Keyword.get(opts, :redactors, [])
    hostname = Keyword.get(opts, :hostname, :system)

    metadata_keys_or_selector = Keyword.get(opts, :metadata, [])
    metadata_selector = update_metadata_selector(metadata_keys_or_selector, @processed_metadata_keys)

    message =
      format_message(msg, meta, %{
        binary: &format_binary_message/1,
        structured: &format_structured_message/1,
        crash: &format_crash_reason(&1, &2, meta)
      })

    metadata =
      take_metadata(meta, metadata_selector)
      |> maybe_put(:"dd.span_id", format_span(meta))
      |> maybe_put(:"dd.trace_id", format_trace(meta))
      |> maybe_update(:otel_span_id, &safe_chardata_to_string/1)
      |> maybe_update(:otel_trace_id, &safe_chardata_to_string/1)

    line =
      %{syslog: syslog(level, meta, hostname)}
      |> maybe_put(:logger, format_logger(meta))
      |> maybe_merge(format_http_request(meta))
      |> maybe_merge(encode(metadata, redactors))
      |> maybe_merge(encode(message, redactors))
      |> @encoder.encode_to_iodata!(encoder_opts)

    [line, "\n"]
  end

  @doc false
  def format_binary_message(binary) do
    %{message: IO.chardata_to_string(binary)}
  end

  @doc false
  def format_structured_message(map) when is_map(map) do
    %{message: map}
  end

  def format_structured_message(keyword) do
    %{message: Enum.into(keyword, %{})}
  end

  @doc false
  def format_crash_reason(binary, {%{} = _exception, stacktrace}, _meta) do
    %{
      error: %{
        message: IO.chardata_to_string(binary),
        stack: Exception.format_stacktrace(stacktrace)
      }
    }
  end

  # https://docs.datadoghq.com/standard-attributes/?search=logger+error&product=log+management
  def format_crash_reason(binary, _other, _meta) do
    %{
      error: %{
        message: binary
      }
    }
  end

  defp syslog(level, meta, :system) do
    {:ok, hostname} = :inet.gethostname()

    %{
      hostname: to_string(hostname),
      severity: Atom.to_string(level),
      timestamp: utc_time(meta)
    }
  end

  defp syslog(level, meta, :unset) do
    %{
      severity: Atom.to_string(level),
      timestamp: utc_time(meta)
    }
  end

  defp syslog(level, meta, hostname) do
    %{
      hostname: hostname,
      severity: Atom.to_string(level),
      timestamp: utc_time(meta)
    }
  end

  defp format_logger(%{file: file, line: line, mfa: {m, f, a}} = meta) do
    %{
      thread_name: inspect(meta[:pid]),
      method_name: format_function(m, f, a),
      file_name: IO.chardata_to_string(file),
      line: line
    }
  end

  defp format_logger(_meta),
    do: nil

  # To connect logs and traces, span_id and trace_id keys are respectively dd.span_id and dd.trace_id
  # https://docs.datadoghq.com/tracing/faq/why-cant-i-see-my-correlated-logs-in-the-trace-id-panel/?tab=jsonlogs
  defp format_span(%{otel_span_id: otel_span_id}), do: convert_otel_field(otel_span_id)
  defp format_span(%{span_id: span_id}), do: span_id
  defp format_span(_meta), do: nil

  defp format_trace(%{otel_trace_id: otel_trace_id}), do: convert_otel_field(otel_trace_id)
  defp format_trace(%{trace_id: trace_id}), do: trace_id
  defp format_trace(_meta), do: nil

  # This converts native OpenTelemetry fields to the native Datadog format.
  # This function is taken from the Datadog examples for converting. Mostly the Golang version
  # https://docs.datadoghq.com/tracing/other_telemetry/connect_logs_and_traces/opentelemetry/?tab=go
  # Tests were stolen from https://github.com/open-telemetry/opentelemetry-specification/issues/525
  # and https://go.dev/play/p/pUBHcLdXJNy
  defp convert_otel_field(<<value::binary-size(16)>>) do
    {value, _} = Integer.parse(value, 16)
    Integer.to_string(value, 10)
  rescue
    _ -> ""
  end

  defp convert_otel_field(value) when byte_size(value) < 16, do: ""

  defp convert_otel_field(value) when is_binary(value) or is_list(value) do
    value = to_string(value)
    len = byte_size(value) - 16
    <<_front::binary-size(len), value::binary>> = value
    convert_otel_field(value)
  rescue
    _ -> ""
  end

  defp convert_otel_field(_other) do
    ""
  end

  defp safe_chardata_to_string(chardata) when is_list(chardata) or is_binary(chardata) do
    IO.chardata_to_string(chardata)
  end

  defp safe_chardata_to_string(other), do: other

  if Code.ensure_loaded?(Plug.Conn) do
    defp format_http_request(%{conn: %Plug.Conn{} = conn, duration_us: duration_us} = meta) do
      conn
      |> build_http_request_data(meta[:request_id])
      |> maybe_put(:duration, to_nanosecs(duration_us))
    end

    defp format_http_request(%{conn: %Plug.Conn{} = conn}), do: format_http_request(%{conn: conn, duration_us: nil})
  end

  defp format_http_request(_meta), do: nil

  if Code.ensure_loaded?(Plug.Conn) do
    Formatter.with Jason do
      require Jason.Helpers

      defp build_http_request_data(%Plug.Conn{} = conn, request_id) do
        request_url = Plug.Conn.request_url(conn)
        user_agent = Formatter.Plug.get_header(conn, "user-agent")
        remote_ip = Formatter.Plug.remote_ip(conn)
        referer = Formatter.Plug.get_header(conn, "referer")

        %{
          http:
            Jason.Helpers.json_map(
              url: request_url,
              status_code: conn.status,
              method: conn.method,
              referer: referer,
              request_id: request_id,
              useragent: user_agent,
              url_details:
                Jason.Helpers.json_map(
                  host: conn.host,
                  port: conn.port,
                  path: conn.request_path,
                  queryString: conn.query_string,
                  scheme: conn.scheme
                )
            ),
          network: Jason.Helpers.json_map(client: Jason.Helpers.json_map(ip: remote_ip))
        }
      end
    else
      defp build_http_request_data(%Plug.Conn{} = conn, request_id) do
        request_url = Plug.Conn.request_url(conn)
        user_agent = Formatter.Plug.get_header(conn, "user-agent")
        remote_ip = Formatter.Plug.remote_ip(conn)
        referer = Formatter.Plug.get_header(conn, "referer")

        %{
          http: %{
            url: request_url,
            status_code: conn.status,
            method: conn.method,
            referer: referer,
            request_id: request_id,
            useragent: user_agent,
            url_details: %{
              host: conn.host,
              port: conn.port,
              path: conn.request_path,
              queryString: conn.query_string,
              scheme: conn.scheme
            }
          },
          network: %{client: %{ip: remote_ip}}
        }
      end
    end
  end

  if Code.ensure_loaded?(Plug.Conn) do
    defp to_nanosecs(duration_us) when is_number(duration_us), do: duration_us * 1000
    defp to_nanosecs(_), do: nil
  end
end
