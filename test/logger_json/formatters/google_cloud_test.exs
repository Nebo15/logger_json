defmodule LoggerJSON.Formatters.GoogleCloudTest do
  use LoggerJSON.Case
  use ExUnitProperties
  alias LoggerJSON.Formatters.GoogleCloud
  require Logger

  @encoder LoggerJSON.Formatter.encoder()

  setup do
    formatter = GoogleCloud.new(metadata: :all, project_id: "myproj-101")
    :logger.update_handler_config(:default, :formatter, formatter)
  end

  property "allows to log any binary messages" do
    check all message <- StreamData.binary() do
      assert capture_log(fn ->
               Logger.debug(message)
             end)
             |> @encoder.decode!()
    end
  end

  property "allows to log any structured messages" do
    check all message <- StreamData.map_of(StreamData.atom(:alphanumeric), StreamData.term()) do
      assert capture_log(fn ->
               Logger.debug(message)
             end)
             |> @encoder.decode!()
    end

    check all message <- StreamData.keyword_of(StreamData.term()) do
      assert capture_log(fn ->
               Logger.debug(message)
             end)
             |> @encoder.decode!()
    end
  end

  test "logs an LogEntry of a given level" do
    for level <- [:error, :info, :debug, :emergency, :alert, :critical, :warning, :notice] do
      log_entry =
        capture_log(level, fn ->
          Logger.log(level, "Hello")
        end)
        |> decode_or_print_error()

      pid = inspect(self())
      level_string = String.upcase(to_string(level))

      assert %{
               "logging.googleapis.com/operation" => %{"producer" => ^pid},
               "logging.googleapis.com/sourceLocation" => %{
                 "file" => _,
                 "function" => _,
                 "line" => _
               },
               "domain" => ["elixir"],
               "message" => "Hello",
               "severity" => ^level_string,
               "time" => _
             } = log_entry
    end
  end

  test "logs an LogEntry when an operation" do
    log_entry =
      capture_log(:info, fn ->
        Logger.log(:info, "Hello", request_id: "1234567890")
      end)
      |> decode_or_print_error()

    pid = inspect(self())

    assert %{
             "logging.googleapis.com/operation" => %{"producer" => ^pid, "id" => "1234567890"}
           } = log_entry
  end

  test "logs an LogEntry with a map payload" do
    log_entry =
      capture_log(fn ->
        Logger.debug(%{foo: :bar, fiz: [1, 2, 3, "buz"]})
      end)
      |> decode_or_print_error()

    assert %{
             "fiz" => [1, 2, 3, "buz"],
             "foo" => "bar"
           } = log_entry
  end

  test "logs an LogEntry with a keyword payload" do
    log_entry =
      capture_log(fn ->
        Logger.debug(a: {0, false})
      end)
      |> decode_or_print_error()

    assert %{
             "a" => [0, false]
           } = log_entry
  end

  test "logs OpenTelemetry span and trace ids" do
    Logger.metadata(
      otel_span_id: ~c"bff20904aa5883a6",
      otel_trace_flags: ~c"01",
      otel_trace_id: ~c"294740ce41cc9f202dedb563db123532"
    )

    log_entry =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()

    assert log_entry["logging.googleapis.com/spanId"] == "bff20904aa5883a6"
    assert log_entry["logging.googleapis.com/trace"] == "projects/myproj-101/traces/294740ce41cc9f202dedb563db123532"
  end

  test "logs span and trace ids without project_id" do
    formatter = GoogleCloud.new(metadata: :all)
    :logger.update_handler_config(:default, :formatter, formatter)

    Logger.metadata(
      otel_span_id: ~c"bff20904aa5883a6",
      otel_trace_flags: ~c"01",
      otel_trace_id: ~c"294740ce41cc9f202dedb563db123532"
    )

    log_entry =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()

    assert log_entry["logging.googleapis.com/spanId"] == "bff20904aa5883a6"
    assert log_entry["logging.googleapis.com/trace"] == "294740ce41cc9f202dedb563db123532"
  end

  test "logs span and trace ids" do
    Logger.metadata(
      span_id: "bff20904aa5883a6",
      trace_id: "294740ce41cc9f202dedb563db123532"
    )

    log_entry =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()

    assert log_entry["logging.googleapis.com/spanId"] == "bff20904aa5883a6"
    assert log_entry["logging.googleapis.com/trace"] == "294740ce41cc9f202dedb563db123532"
  end

  test "does not crash on invalid span and trace ids" do
    Logger.metadata(
      span_id: :foo,
      trace_id: 123
    )

    log_entry =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()

    assert log_entry["logging.googleapis.com/spanId"] == "foo"
    assert log_entry["logging.googleapis.com/trace"] == 123
  end

  test "does not crash on invalid OTEL span and trace ids" do
    formatter = GoogleCloud.new(metadata: :all)
    :logger.update_handler_config(:default, :formatter, formatter)

    Logger.metadata(
      otel_span_id: :foo,
      otel_trace_id: 123
    )

    log_entry =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()

    assert log_entry["logging.googleapis.com/spanId"] == "foo"
    assert log_entry["logging.googleapis.com/trace"] == 123
  end

  test "logs request id" do
    Logger.metadata(request_id: "1234567890")

    log_entry =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()

    assert log_entry["logging.googleapis.com/operation"]["id"] == "1234567890"

    assert log_entry["request_id"] == "1234567890"
  end

  test "logs metadata" do
    Logger.metadata(
      date: Date.utc_today(),
      time: Time.new(10, 10, 11),
      pid: self(),
      ref: make_ref(),
      atom: :atom,
      list: [1, 2, 3],
      map: %{foo: :bar},
      struct: URI.parse("https://example.com"),
      binary: "binary",
      node: node()
    )

    log_entry =
      capture_log(fn ->
        Logger.debug("Hello", float: 3.14)
      end)
      |> decode_or_print_error()

    assert %{
             "atom" => "atom",
             "binary" => "binary",
             "date" => _,
             "domain" => ["elixir"],
             "list" => [1, 2, 3],
             "map" => %{"foo" => "bar"},
             "message" => "Hello",
             "node" => "nonode@nohost",
             "ref" => _ref,
             "float" => 3.14,
             "struct" => %{
               "authority" => "example.com",
               "fragment" => nil,
               "host" => "example.com",
               "path" => nil,
               "port" => 443,
               "query" => nil,
               "scheme" => "https",
               "userinfo" => nil
             }
           } = log_entry
  end

  test "logs exceptions" do
    log_entry =
      capture_log(fn ->
        pid =
          spawn(fn ->
            raise RuntimeError
          end)

        ref = Process.monitor(pid)
        assert_receive {:DOWN, ^ref, _, _, _}
        Process.sleep(100)
      end)
      |> decode_or_print_error()

    assert %{
             "@type" => "type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent",
             "message" => "runtime error",
             "stack_trace" => stacktrace,
             "serviceContext" => %{"service" => "nonode@nohost"}
           } = log_entry

    assert stacktrace =~ "** (RuntimeError) runtime error"
    assert stacktrace =~ "test/"
    assert stacktrace =~ ":in `"
  end

  test "logged exception stacktrace is in Ruby format for Elixir errors" do
    error = %RuntimeError{message: "oops"}

    stacktrace = [
      {Foo, :bar, 0, [file: ~c"foo/bar.ex", line: 123]},
      {Foo.Bar, :baz, 1, [file: ~c"foo/bar/baz.ex", line: 456]}
    ]

    Logger.metadata(crash_reason: {error, stacktrace})

    log_entry =
      capture_log(fn ->
        Logger.debug("foo")
      end)
      |> decode_or_print_error()

    assert log_entry["stack_trace"] ==
             """
             ** (RuntimeError) oops
                 foo/bar.ex:123:in `Foo.bar/0'
                 foo/bar/baz.ex:456:in `Foo.Bar.baz/1'
             """
  end

  test "logs exception user context" do
    Logger.metadata(crash_reason: {{:EXIT, self()}, :foo})

    # The keys are applied in the order of their precedence
    [:user_id, :identity_id, :actor_id, :account_id]
    |> Enum.reverse()
    |> Enum.reduce([], fn key, metadata ->
      metadata = Keyword.put(metadata, key, "foo_#{key}")
      Logger.metadata(metadata)

      log_entry =
        capture_log(fn ->
          Logger.debug("Hello")
        end)
        |> decode_or_print_error()

      [entity, _id] = key |> Atom.to_string() |> String.split("_")

      assert log_entry["context"]["user"] == "#{entity}:foo_#{key}"

      metadata
    end)
  end

  test "logs http context" do
    conn =
      Plug.Test.conn("GET", "/", "")
      |> Plug.Conn.put_req_header("user-agent", "Mozilla/5.0")
      |> Plug.Conn.put_req_header("referer", "http://www.example2.com/")
      |> Plug.Conn.put_req_header("x-forwarded-for", "")
      |> Plug.Conn.send_resp(200, "Hi!")

    Logger.metadata(conn: conn)

    log_entry =
      capture_log(fn ->
        Logger.debug("Hello", duration_us: 123_456)
      end)
      |> decode_or_print_error()

    assert log_entry["httpRequest"] == %{
             "protocol" => "HTTP/1.1",
             "referer" => "http://www.example2.com/",
             "remoteIp" => "",
             "requestMethod" => "GET",
             "requestUrl" => "http://www.example.com/",
             "status" => 200,
             "userAgent" => "Mozilla/5.0",
             "latency" => "0.123456s"
           }
  end

  test "logs exception http context" do
    conn =
      Plug.Test.conn("patch", "/", "")
      |> Plug.Conn.put_req_header("user-agent", "Mozilla/5.0")
      |> Plug.Conn.put_req_header("referer", "http://www.example.com/")
      |> Plug.Conn.put_req_header("x-forwarded-for", "")
      |> Plug.Conn.send_resp(503, "oops")

    Logger.metadata(crash_reason: {{:EXIT, self()}, :foo}, conn: conn)

    log_entry =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()

    assert log_entry["context"]["httpRequest"] == %{
             "protocol" => "HTTP/1.1",
             "referer" => "http://www.example.com/",
             "remoteIp" => "",
             "requestMethod" => "PATCH",
             "requestUrl" => "http://www.example.com/",
             "status" => 503,
             "userAgent" => "Mozilla/5.0",
             "latency" => nil
           }
  end

  test "logs throws" do
    Logger.metadata(crash_reason: {:throw, {:error, :whatever}})

    log_entry =
      capture_log(fn ->
        Logger.debug("oops!")
      end)
      |> decode_or_print_error()

    assert %{
             "@type" => "type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent",
             "message" => "oops!",
             "stack_trace" => "** (throw) {:error, :whatever}",
             "serviceContext" => %{"service" => "nonode@nohost"},
             "context" => %{
               "reportLocation" => %{
                 "filePath" => _,
                 "functionName" => _,
                 "lineNumber" => _
               }
             }
           } = log_entry
  end

  test "logs exits" do
    Logger.metadata(crash_reason: {:exit, :sad_failure})

    log_entry =
      capture_log(fn ->
        Logger.debug("oops!")
      end)
      |> decode_or_print_error()

    assert %{
             "@type" => "type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent",
             "message" => "oops!",
             "stack_trace" => "** (exit) :sad_failure",
             "serviceContext" => %{"service" => "nonode@nohost"}
           } = log_entry
  end

  test "logs Task/GenServer termination" do
    test_pid = self()

    logs =
      capture_log(fn ->
        {:ok, _} = Supervisor.start_link([{CrashingGenServer, :ok}], strategy: :one_for_one)

        {:ok, _} =
          Task.start(fn ->
            try do
              GenServer.call(CrashingGenServer, :boom)
            catch
              _ -> nil
            after
              send(test_pid, :done)
            end
          end)

        # Wait for task to finish
        receive do
          :done -> nil
        end

        # Let logs flush
        Process.sleep(100)
      end)

    [_, log_entry] =
      logs
      |> String.trim()
      |> String.split("\n")
      |> Enum.map(&decode_or_print_error/1)

    assert %{
             "@type" => "type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent",
             "message" => message,
             "stack_trace" => "** (RuntimeError) boom" <> _,
             "serviceContext" => %{"service" => "nonode@nohost"}
           } = log_entry

    assert message =~ ~r/Task #PID<\d+.\d+.\d+> started from #{inspect(test_pid)} terminating/
  end

  test "does not crash on unknown error tuples" do
    Logger.metadata(crash_reason: {{:something, :else}, [:unknown]})

    log_entry =
      capture_log(fn ->
        Logger.debug("oops!")
      end)
      |> decode_or_print_error()

    assert %{
             "@type" => "type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent",
             "message" => "oops!",
             "stack_trace" => "** ({:something, :else}) [:unknown]",
             "serviceContext" => %{"service" => "nonode@nohost"}
           } = log_entry
  end

  test "does not crash on unknown errors" do
    Logger.metadata(crash_reason: :what_is_this?)

    log_entry =
      capture_log(fn ->
        Logger.debug("oops!")
      end)
      |> decode_or_print_error()

    assert %{
             "@type" => "type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent",
             "message" => "oops!",
             "stack_trace" => nil,
             "serviceContext" => %{"service" => "nonode@nohost"}
           } = log_entry
  end

  test "logs process exits" do
    Logger.metadata(crash_reason: {{:EXIT, self()}, :sad_failure})

    log_entry =
      capture_log(fn ->
        Logger.debug("oops!")
      end)
      |> decode_or_print_error()

    assert %{
             "@type" => "type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent",
             "message" => "oops!",
             "stack_trace" => stacktrace,
             "serviceContext" => %{"service" => "nonode@nohost"}
           } = log_entry

    assert stacktrace =~ "** (EXIT from #PID<"
    assert stacktrace =~ ">) :sad_failure"
  end

  test "logs reasons in tuple" do
    Logger.metadata(crash_reason: {:socket_closed_unexpectedly, []})

    log_entry =
      capture_log(fn ->
        Logger.debug("oops!")
      end)
      |> decode_or_print_error()

    assert %{
             "@type" => "type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent",
             "message" => "oops!",
             "stack_trace" => "** (socket_closed_unexpectedly) []",
             "serviceContext" => %{"service" => "nonode@nohost"}
           } = log_entry
  end

  if @encoder == Jason do
    test "passing options to encoder" do
      formatter = GoogleCloud.new(encoder_opts: [pretty: true])
      :logger.update_handler_config(:default, :formatter, formatter)

      assert capture_log(fn ->
               Logger.debug("Hello")
             end) =~
               ~r/\n\s{2}"message": "Hello"/
    end
  end

  test "reads metadata from the given application env" do
    Application.put_env(:logger_json, :test_google_cloud_metadata_key, [:foo])
    formatter = GoogleCloud.new(metadata: {:from_application_env, {:logger_json, :test_google_cloud_metadata_key}})
    :logger.update_handler_config(:default, :formatter, formatter)

    Logger.metadata(foo: "foo")

    log =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()

    assert %{
             "foo" => "foo"
           } = log
  end

  test "reads metadata from the given application env at given path" do
    Application.put_env(:logger_json, :test_google_cloud_metadata_key, metadata: [:foo])

    formatter =
      GoogleCloud.new(metadata: {:from_application_env, {:logger_json, :test_google_cloud_metadata_key}, [:metadata]})

    :logger.update_handler_config(:default, :formatter, formatter)

    Logger.metadata(foo: "foo")

    log =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()

    assert %{
             "foo" => "foo"
           } = log
  end
end
