defmodule LoggerJSON.Formatters.GoogleCloud do
  @moduledoc """
  Custom Erlang's [`:logger` formatter](https://www.erlang.org/doc/apps/kernel/logger_chapter.html#formatters) which
  writes logs in a structured format that can be consumed by Google Cloud Logger.

  Even though the log messages on Google Cloud use [LogEntry](https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry)
  format, not all the fields are available in the structured payload. The fields that are available can be found in the
  [special fields in structured payloads](https://cloud.google.com/logging/docs/agent/configuration#special_fields_in_structured_payloads).

  ## Formatter Configuration

  The formatter can be configured with the following options:

  * `:project_id` (optional) - the Google Cloud project ID. This is required for correctly logging OpenTelemetry trace and
  span IDs so that they can be linked to the correct trace in Google Cloud Trace.

  * `:service_context` (optional) - a map with the following keys:
    * `:service` - the name of the service that is logging the message. Default: `node()`.
    * `:version` - the version of the service that is logging the message.

  For list of shared options see "Shared options" in `LoggerJSON`.

  ## Metadata

  You can extend the log entry with some additional metadata:application

    * `user_id`, `identity_id`, `actor_id`, `account_id` (ordered by precedence) - the ID of the user that is performing the action.
    It will be included along with the error report for Google Cloud Error Reporting;

  For list of other well-known metadata keys see "Metadata" in `LoggerJSON`.

  ## Examples

  Regular message:

      %{
        "logging.googleapis.com/operation" => %{"pid" => "#PID<0.228.0>"},
        "logging.googleapis.com/sourceLocation" => %{
          "file" => "/Users/andrew/Projects/os/logger_json/test/formatters/google_cloud_test.exs",
          "function" => "Elixir.LoggerJSON.Formatters.GoogleCloudTest.test logs an LogEntry of a given level/1",
          "line" => 44
        },
        "message" => %{"domain" => ["elixir"], "message" => "Hello"},
        "severity" => "NOTICE",
        "time" => "2024-04-11T21:32:46.957Z"
      }

  Exception message that will be recognized by Google Cloud Error Reporting:

      %{
        "httpRequest" => %{
          "protocol" => "HTTP/1.1",
          "referer" => "http://www.example.com/",
          "remoteIp" => "",
          "requestMethod" => "PATCH",
          "requestUrl" => "http://www.example.com/",
          "status" => 503,
          "userAgent" => "Mozilla/5.0"
        },
        "logging.googleapis.com/operation" => %{"pid" => "#PID<0.250.0>"},
        "logging.googleapis.com/sourceLocation" => %{
          "file" => "/Users/andrew/Projects/os/logger_json/test/formatters/google_cloud_test.exs",
          "function" => "Elixir.LoggerJSON.Formatters.GoogleCloudTest.test logs exception http context/1",
          "line" => 301
        },
        "@type" => "type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent",
        "context" => %{
          "httpRequest" => %{
            "protocol" => "HTTP/1.1",
            "referer" => "http://www.example.com/",
            "remoteIp" => "",
            "requestMethod" => "PATCH",
            "requestUrl" => "http://www.example.com/",
            "status" => 503,
            "userAgent" => "Mozilla/5.0"
          },
          "reportLocation" => %{
            "filePath" => "/Users/andrew/Projects/os/logger_json/test/formatters/google_cloud_test.exs",
            "functionName" => "Elixir.LoggerJSON.Formatters.GoogleCloudTest.test logs exception http context/1",
            "lineNumber" => 301
          }
        },
        "domain" => ["elixir"],
        "message" => "Hello",
        "serviceContext" => %{"service" => "nonode@nohost"},
        "stack_trace" => "** (EXIT from #PID<0.250.0>) :foo",
        "severity" => "DEBUG",
        "time" => "2024-04-11T21:34:53.503Z"
      }
  """
  import Jason.Helpers, only: [json_map: 1]
  import LoggerJSON.Formatter.{MapBuilder, DateTime, Message, Metadata, Code, Plug, RedactorEncoder}

  @behaviour LoggerJSON.Formatter

  @processed_metadata_keys ~w[pid file line mfa
                              otel_span_id span_id
                              otel_trace_id trace_id
                              conn]a

  @impl true
  def format(%{level: level, meta: meta, msg: msg}, opts) do
    redactors = Keyword.get(opts, :redactors, [])
    service_context = Keyword.get_lazy(opts, :service_context, fn -> %{service: to_string(node())} end)
    project_id = Keyword.get(opts, :project_id)
    metadata_keys_or_selector = Keyword.get(opts, :metadata, [])
    metadata_selector = update_metadata_selector(metadata_keys_or_selector, @processed_metadata_keys)

    message =
      format_message(msg, meta, %{
        binary: &format_binary_message/1,
        structured: &format_structured_message/1,
        crash: &format_crash_reason(&1, &2, service_context, meta)
      })

    metadata =
      take_metadata(meta, metadata_selector)

    line =
      %{
        time: utc_time(meta),
        severity: log_level(level)
      }
      |> maybe_put(:"logging.googleapis.com/sourceLocation", format_source_location(meta))
      |> maybe_put(:"logging.googleapis.com/operation", format_operation(meta))
      |> maybe_put(:"logging.googleapis.com/spanId", format_span(meta, project_id))
      |> maybe_put(:"logging.googleapis.com/trace", format_trace(meta, project_id))
      |> maybe_put(:httpRequest, format_http_request(meta))
      |> maybe_merge(encode(message, redactors))
      |> maybe_merge(encode(metadata, redactors))
      |> Jason.encode_to_iodata!()

    [line, "\n"]
  end

  defp log_level(:emergency), do: "EMERGENCY"
  defp log_level(:alert), do: "ALERT"
  defp log_level(:critical), do: "CRITICAL"
  defp log_level(:error), do: "ERROR"
  defp log_level(:warning), do: "WARNING"
  defp log_level(:notice), do: "NOTICE"
  defp log_level(:info), do: "INFO"
  defp log_level(:debug), do: "DEBUG"

  @doc false
  def format_binary_message(binary) do
    %{message: IO.chardata_to_string(binary)}
  end

  @doc false
  def format_structured_message(map) when is_map(map) do
    map
  end

  def format_structured_message(keyword) do
    Enum.into(keyword, %{})
  end

  @doc false
  # https://cloud.google.com/error-reporting/docs/formatting-error-messages
  def format_crash_reason(binary, {{:EXIT, pid}, reason}, service_context, meta) do
    stacktrace = Exception.format_banner({:EXIT, pid}, reason, [])
    format_reported_error_event(binary, stacktrace, service_context, meta)
  end

  def format_crash_reason(binary, {:exit, reason}, service_context, meta) do
    stacktrace = Exception.format_banner(:exit, reason, [])
    format_reported_error_event(binary, stacktrace, service_context, meta)
  end

  def format_crash_reason(binary, {:throw, reason}, service_context, meta) do
    stacktrace = Exception.format_banner(:throw, reason, [])
    format_reported_error_event(binary, stacktrace, service_context, meta)
  end

  def format_crash_reason(_binary, {%{} = exception, stacktrace}, service_context, meta) do
    message = Exception.message(exception)

    ruby_stacktrace =
      [
        Exception.format_banner(:error, exception, stacktrace),
        format_stacktrace(stacktrace)
      ]
      |> Enum.join("\n")

    format_reported_error_event(message, ruby_stacktrace, service_context, meta)
  end

  def format_crash_reason(binary, {error, reason}, service_context, meta) do
    stacktrace = "** (#{error}) #{inspect(reason)}"
    format_reported_error_event(binary, stacktrace, service_context, meta)
  end

  defp format_reported_error_event(message, stacktrace, service_context, meta) do
    %{
      "@type": "type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent",
      stack_trace: stacktrace,
      message: IO.chardata_to_string(message),
      context: format_reported_error_event_context(meta),
      serviceContext: service_context
    }
  end

  # https://cloud.google.com/error-reporting/docs/formatting-error-messages#reported-error-example
  defp format_reported_error_event_context(meta) do
    %{}
    |> maybe_put(:reportLocation, format_crash_report_location(meta))
    |> maybe_put(:httpRequest, format_http_request(meta))
    |> maybe_put(:user, format_affected_user(meta))
  end

  defp format_crash_report_location(%{file: file, line: line, mfa: {m, f, a}}) do
    %{
      filePath: IO.chardata_to_string(file),
      lineNumber: line,
      functionName: format_function(m, f, a)
    }
  end

  defp format_crash_report_location(_meta), do: nil

  if Code.ensure_loaded?(Plug.Conn) do
    defp format_http_request(%{conn: %Plug.Conn{} = conn}) do
      request_method = conn.method |> to_string() |> String.upcase()
      request_url = Plug.Conn.request_url(conn)
      status = conn.status
      user_agent = get_header(conn, "user-agent")
      remote_ip = remote_ip(conn)
      referer = get_header(conn, "referer")

      json_map(
        protocol: Plug.Conn.get_http_protocol(conn),
        requestMethod: request_method,
        requestUrl: request_url,
        status: status,
        userAgent: user_agent,
        remoteIp: remote_ip,
        referer: referer
      )
    end
  end

  defp format_http_request(_meta), do: nil

  defp format_affected_user(%{user_id: user_id}), do: "user:" <> user_id
  defp format_affected_user(%{identity_id: identity_id}), do: "identity:" <> identity_id
  defp format_affected_user(%{actor_id: actor_id}), do: "actor:" <> actor_id
  defp format_affected_user(%{account_id: account_id}), do: "account:" <> account_id
  defp format_affected_user(_meta), do: nil

  defp format_stacktrace(stacktrace) do
    lines =
      Exception.format_stacktrace(stacktrace)
      |> String.trim_trailing()
      |> String.split("\n")
      |> Enum.map(&format_line/1)
      |> Enum.group_by(fn {kind, _line} -> kind end)

    lines = format_lines(:trace, lines[:trace]) ++ format_lines(:context, lines[:context]) ++ [""]

    Enum.join(lines, "\n")
  end

  defp format_line(line) do
    case Regex.run(~r/(.+)\:(\d+)\: (.*)/, line) do
      [_, file, line, function] ->
        {:trace, "#{file}:#{line}:in `#{function}'"}

      # There is no way how Exception.format_stacktrace/1 can return something
      # that does not match the clause above, but we keep this clause "just in case"
      # coveralls-ignore-next-line
      _ ->
        {:context, line}
    end
  end

  defp format_lines(_kind, nil) do
    []
  end

  defp format_lines(:trace, lines) do
    Enum.map(lines, fn {:trace, line} -> line end)
  end

  # There is no way how Exception.format_stacktrace/1 can return context at the moment
  # coveralls-ignore-start
  defp format_lines(:context, lines) do
    ["Context:" | Enum.map(lines, fn {:context, line} -> line end)]
  end

  # coveralls-ignore-stop

  # https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry#LogEntryOperation
  defp format_operation(%{request_id: request_id, pid: pid}), do: json_map(id: request_id, producer: inspect(pid))
  defp format_operation(%{pid: pid}), do: json_map(producer: inspect(pid))
  # Erlang logger always has `pid` in the metadata but we keep this clause "just in case"
  # coveralls-ignore-next-line
  defp format_operation(_meta), do: nil

  # https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry#LogEntrySourceLocation
  defp format_source_location(%{file: file, line: line, mfa: {m, f, a}}) do
    json_map(
      file: IO.chardata_to_string(file),
      line: line,
      function: format_function(m, f, a)
    )
  end

  defp format_source_location(_meta),
    do: nil

  defp format_span(%{otel_span_id: otel_span_id}, _project_id_or_nil),
    do: safe_chardata_to_string(otel_span_id)

  defp format_span(%{span_id: span_id}, _project_id_or_nil),
    do: span_id

  defp format_span(_meta, _project_id_or_nil),
    do: nil

  defp format_trace(%{otel_trace_id: otel_trace_id}, nil),
    do: safe_chardata_to_string(otel_trace_id)

  defp format_trace(%{otel_trace_id: otel_trace_id}, project_id),
    do: "projects/#{project_id}/traces/#{safe_chardata_to_string(otel_trace_id)}"

  defp format_trace(%{trace_id: trace_id}, _project_id_or_nil),
    do: trace_id

  defp format_trace(_meta, _project_id_or_nil),
    do: nil

  defp safe_chardata_to_string(chardata) when is_list(chardata) or is_binary(chardata) do
    IO.chardata_to_string(chardata)
  end

  defp safe_chardata_to_string(other), do: other
end
