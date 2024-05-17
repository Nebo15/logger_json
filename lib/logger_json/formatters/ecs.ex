defmodule LoggerJSON.Formatters.ECS do
  @moduledoc """
  Custom Erlang's [`:logger` formatter](https://www.erlang.org/doc/apps/kernel/logger_chapter.html#formatters) which
  writes logs in a JSON-structured format that conforms to the Elastic Common Schema (ECS), so it can be consumed by
  the Elastic Stack.

  ## Formatter Configuration

  For list of options see "Shared options" in `LoggerJSON`.

  ## Metadata

  For list of other well-known metadata keys see "Metadata" in `LoggerJSON`.

  Any custom metadata that you set with `Logger.metadata/1` will be included top-level in the log entry.

  ## Examples

  Example of an info log (`Logger.info("Hello")` without any metadata):

      %{
        "@timestamp" => "2024-05-17T16:20:00.000Z",
        "ecs.version" => "8.11.0",
        "log.level" => "info",
        "log.logger" => "Elixir.LoggerJSON.Formatters.ECSTest",
        "log.origin" => %{
          "file.name" => ~c"/app/logger_json/test/formatters/ecs_test.exs",
          "file.line" => 18,
          "function" => "test logs an LogEntry of every level/1"
        },
        "message" => "Hello"
      }

  Example of logging by keywords or by map (Logger.info(%{message: "Hello", foo: :bar, fiz: %{buz: "buz"}})).
  The keywords or map items are added to the top-level of the log entry:

      %{
        "@timestamp" => "2024-05-17T16:20:00.000Z",
        "ecs.version" => "8.11.0",
        "fiz" => %{"buz" => "buz"},
        "foo" => "bar",
        "log.level" => "debug",
        "log.logger" => "Elixir.LoggerJSON.Formatters.ECSTest",
        "log.origin" => %{
          "file.line" => 68,
          "file.name" => ~c"/app/logger_json/test/formatters/ecs_test.exs",
          "function" => "test logs an LogEntry with a map payload containing message/1"},
        "message" => "Hello"
      }

  Example of logging due to raising an exception (`raise RuntimeError`):

      %{
        "@timestamp" => "2024-05-17T16:20:00.000Z",
        "ecs.version" => "8.11.0",
        "error.message" => "runtime error",
        "error.stack_trace" => "** (RuntimeError) runtime error\\n    Elixir.LoggerJSON.Formatters.ECSTest.erl:159: anonymous fn/4 in LoggerJSON.Formatters.ECSTest.\\"test logs exceptions\\"/1\\n",
        "error.type" => "Elixir.RuntimeError",
        "log.level" => "error",
        "message" => "runtime error"
      }

  Note that if you raise an exception that contains an `id` or a `code` property, they will be included in the log entry as `error.id` and `error.code` respectively.

  Example:

      defmodule TestException do
        defexception [:message, :id, :code]
      end

      ...

      raise TestException, id: :oops_id, code: 42, message: "oops!"

  results in:

      %{
        "@timestamp" => "2024-05-17T16:20:00.000Z",
        "ecs.version" => "8.11.0",
        "error.code" => 42,
        "error.id" => "oops_id",
        "error.message" => "oops!",
        "error.stack_trace" => "** (LoggerJSON.Formatters.ECSTest.TestException) oops!\n    test/formatters/ecs_test.exs:190: anonymous fn/0 in LoggerJSON.Formatters.ECSTest.\"test logs exceptions with id and code\"/1\n",
        "error.type" => "Elixir.LoggerJSON.Formatters.ECSTest.TestException",
        "log.level" => "error",
        "message" => "oops!"
      }
  """
  import Jason.Helpers, only: [json_map: 1]
  import LoggerJSON.Formatter.{MapBuilder, DateTime, Message, Metadata, Plug, Encoder}

  @ecs_version "8.11.0"

  @processed_metadata_keys ~w[file line mfa domain error_logger
                              otel_span_id span_id
                              otel_trace_id trace_id
                              conn]a

  @spec format(any(), any()) :: none()
  def format(%{level: level, meta: meta, msg: msg}, opts) do
    metadata_keys_or_selector = Keyword.get(opts, :metadata, [])
    metadata_selector = update_metadata_selector(metadata_keys_or_selector, @processed_metadata_keys)

    message =
      format_message(msg, meta, %{
        binary: &format_binary_message/1,
        structured: &format_structured_message/1,
        crash: &format_crash_reason(&1, &2, meta)
      })

    line =
      %{
        "@timestamp": utc_time(meta),
        "log.level": Atom.to_string(level),
        "ecs.version": @ecs_version
      }
      |> maybe_merge(encode(message))
      |> maybe_merge(encode(take_metadata(meta, metadata_selector)))
      |> maybe_merge(format_logger_fields(meta))
      # |> maybe_put(:request, format_http_request(meta))
      |> maybe_put(:"span.id", format_span_id(meta))
      |> maybe_put(:"trace.id", format_trace_id(meta))
      |> Jason.encode_to_iodata!()

    [line, "\n"]
  end

  def format_binary_message(binary) do
    %{message: IO.chardata_to_string(binary)}
  end

  def format_structured_message(map) when is_map(map) do
    map
  end

  def format_structured_message(keyword) do
    Enum.into(keyword, %{})
  end

  def format_crash_reason(message, {{:EXIT, pid}, reason}, _meta) do
    stacktrace = Exception.format_banner({:EXIT, pid}, reason, [])
    error_message = "process #{inspect(pid)} exit: #{inspect(reason)}"
    format_error_fields(message, error_message, stacktrace, "EXIT")
  end

  def format_crash_reason(message, {:exit, reason}, _meta) do
    stacktrace = Exception.format_banner(:exit, reason, [])
    error_message = "exit: #{inspect(reason)}"
    format_error_fields(message, error_message, stacktrace, "exit")
  end

  def format_crash_reason(message, {:throw, reason}, _meta) do
    stacktrace = Exception.format_banner(:throw, reason, [])
    error_message = "throw: #{inspect(reason)}"
    format_error_fields(message, error_message, stacktrace, "throw")
  end

  def format_crash_reason(_message, {%type{} = exception, stacktrace}, _meta) do
    message = Exception.message(exception)

    formatted_stacktrace =
      [
        Exception.format_banner(:error, exception, stacktrace),
        Exception.format_stacktrace(stacktrace)
      ]
      |> Enum.join("\n")

    format_error_fields(message, message, formatted_stacktrace, type)
    |> maybe_put(:"error.id", get_exception_id(exception))
    |> maybe_put(:"error.code", get_exception_code(exception))
  end

  def format_crash_reason(message, {error, reason}, _meta) do
    stacktrace = "** (#{error}) #{inspect(reason)}"
    error_message = "#{error}: #{inspect(reason)}"
    format_error_fields(message, error_message, stacktrace, error)
  end

  defp get_exception_id(%{id: id}), do: id
  defp get_exception_id(_), do: nil

  defp get_exception_code(%{code: code}), do: code
  defp get_exception_code(_), do: nil

  @doc """
  Formats the error fields as specified in https://www.elastic.co/guide/en/ecs/8.11/ecs-error.html
  """
  def format_error_fields(message, error_message, stacktrace, type) do
    %{
      message: encode(message),
      "error.message": encode(error_message),
      "error.stack_trace": encode(stacktrace),
      "error.type": encode(type)
    }
  end

  @doc """
  Formats the log.logger and log.origin fields as specified in https://www.elastic.co/guide/en/ecs/8.11/ecs-log.html
  """
  def format_logger_fields(%{file: file, line: line, mfa: {module, function, arity}}) do
    %{
      "log.logger": encode(module),
      "log.origin": %{
        "file.name": encode(file),
        "file.line": encode(line),
        function: encode("#{function}/#{arity}")
      }
    }
  end

  def format_logger_fields(_meta), do: nil

  if Code.ensure_loaded?(Plug.Conn) do
    defp format_http_request(%{conn: %Plug.Conn{} = conn}) do
      json_map(
        connection:
          json_map(
            protocol: Plug.Conn.get_http_protocol(conn),
            method: conn.method,
            path: conn.request_path,
            status: conn.status
          ),
        client:
          json_map(
            user_agent: get_header(conn, "user-agent"),
            ip: remote_ip(conn)
          )
      )
    end
  end

  defp format_http_request(_meta), do: nil

  defp format_span_id(%{otel_span_id: otel_span_id}), do: IO.chardata_to_string(otel_span_id)
  defp format_span_id(%{span_id: span_id}), do: span_id
  defp format_span_id(_meta), do: nil

  defp format_trace_id(%{otel_trace_id: otel_trace_id}), do: IO.chardata_to_string(otel_trace_id)
  defp format_trace_id(%{trace_id: trace_id}), do: trace_id
  defp format_trace_id(_meta), do: nil
end
