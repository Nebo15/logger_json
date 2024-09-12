defmodule LoggerJSON.Formatters.ElasticTest do
  use LoggerJSON.Case
  use ExUnitProperties
  alias LoggerJSON.Formatters.Elastic
  require Logger

  setup do
    formatter = {Elastic, metadata: :all}
    :logger.update_handler_config(:default, :formatter, formatter)
  end

  test "logs message of every level" do
    for level <- [:error, :info, :debug, :emergency, :alert, :critical, :warning, :notice] do
      message = "Hello"

      log_entry =
        capture_log(level, fn ->
          Logger.log(level, message)
        end)
        |> decode_or_print_error()

      level_string = Atom.to_string(level)

      assert %{
               "@timestamp" => timestamp,
               "ecs.version" => "8.11.0",
               "log.level" => ^level_string,
               "log.logger" => "Elixir.LoggerJSON.Formatters.ElasticTest",
               "log.origin" => %{
                 "file.name" => origin_file,
                 "file.line" => origin_line,
                 "function" => origin_function
               },
               "message" => ^message
             } = log_entry

      assert {:ok, _, _} = DateTime.from_iso8601(timestamp)
      assert origin_line > 0
      assert String.ends_with?(origin_file, "test/logger_json/formatters/elastic_test.exs")
      assert String.starts_with?(origin_function, "test logs message of every level/1")
      assert log_entry["domain"] == nil
    end
  end

  test "logs message with a map payload" do
    log =
      capture_log(fn ->
        Logger.debug(%{foo: :bar, fiz: [1, 2, 3, "buz"]})
      end)
      |> decode_or_print_error()

    assert log["fiz"] == [1, 2, 3, "buz"]
    assert log["foo"] == "bar"
  end

  test "logs message with a keyword payload" do
    log =
      capture_log(fn ->
        Logger.debug(a: {0, false})
      end)
      |> decode_or_print_error()

    assert log["a"] == [0, false]
  end

  test "logs an LogEntry with a map payload containing message" do
    log =
      capture_log(fn ->
        Logger.debug(%{message: "Hello", foo: :bar, fiz: %{buz: "buz"}})
      end)
      |> decode_or_print_error()

    assert log["message"] == "Hello"
    assert log["foo"] == "bar"
    assert log["fiz"]["buz"] == "buz"
  end

  test "logs OpenTelemetry span and trace ids" do
    Logger.metadata(
      otel_span_id: ~c"bff20904aa5883a6",
      otel_trace_flags: ~c"01",
      otel_trace_id: ~c"294740ce41cc9f202dedb563db123532"
    )

    log =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()

    assert log["span.id"] == "bff20904aa5883a6"
    assert log["trace.id"] == "294740ce41cc9f202dedb563db123532"
  end

  test "logs span and trace ids" do
    Logger.metadata(
      span_id: "bff20904aa5883a6",
      trace_id: "294740ce41cc9f202dedb563db123532"
    )

    log =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()

    assert log["span.id"] == "bff20904aa5883a6"
    assert log["trace.id"] == "294740ce41cc9f202dedb563db123532"
  end

  test "does not crash on invalid span and trace ids" do
    Logger.metadata(
      span_id: :foo,
      trace_id: 123
    )

    log =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()

    assert log["span.id"] == "foo"
    assert log["trace.id"] == 123
  end

  test "does not crash on invalid OTEL span and trace ids" do
    Logger.metadata(
      otel_span_id: :foo,
      otel_trace_id: 123
    )

    log =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()

    assert log["span.id"] == "foo"
    assert log["trace.id"] == 123
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
             "message" => "Hello",
             "atom" => "atom",
             "binary" => "binary",
             "date" => _,
             "list" => [1, 2, 3],
             "map" => %{"foo" => "bar"},
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
             "message" => message,
             "error.message" => "runtime error",
             "error.stack_trace" => stacktrace,
             "error.type" => "Elixir.RuntimeError"
           } = log_entry

    assert message =~ ~r/Process #PID<\d.\d+.\d> raised an exception/
    assert stacktrace =~ "** (RuntimeError) runtime error"
    assert stacktrace =~ ~r/test\/logger_json\/formatters\/elastic_test.exs:\d+: anonymous fn\/0/
    assert stacktrace =~ "in LoggerJSON.Formatters.ElasticTest.\"test logs exceptions\"/1"
    assert log_entry["error_logger"] == nil
  end

  test "logs exceptions with id and code" do
    defmodule TestException do
      defexception [:message, :id, :code]
    end

    log_entry =
      capture_log(fn ->
        pid =
          spawn(fn ->
            raise TestException, id: :oops_id, code: 42, message: "oops!"
          end)

        ref = Process.monitor(pid)
        assert_receive {:DOWN, ^ref, _, _, _}
        Process.sleep(100)
      end)
      |> decode_or_print_error()

    assert %{
             "message" => message,
             "error.message" => "oops!",
             "error.stack_trace" => _,
             "error.type" => "Elixir.LoggerJSON.Formatters.ElasticTest.TestException",
             "error.id" => "oops_id",
             "error.code" => 42
           } = log_entry

    assert message =~ ~r/Process #PID<\d.\d+.\d> raised an exception/
  end

  test "logged exception stacktrace is in default Elixir format" do
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

    assert log_entry["error.stack_trace"] ==
             """
             ** (RuntimeError) oops
                 foo/bar.ex:123: Foo.bar/0
                 foo/bar/baz.ex:456: Foo.Bar.baz/1
             """
  end

  test "logs throws" do
    Logger.metadata(crash_reason: {:throw, {:error, :whatever}})

    log_entry =
      capture_log(fn ->
        Logger.debug("oops!")
      end)
      |> decode_or_print_error()

    assert %{
             "message" => "oops!",
             "error.message" => "throw: {:error, :whatever}",
             "error.stack_trace" => "** (throw) {:error, :whatever}",
             "error.type" => "throw",
             "log.logger" => "Elixir.LoggerJSON.Formatters.ElasticTest",
             "log.origin" => %{
               "file.line" => _,
               "file.name" => _,
               "function" => _
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
             "message" => "oops!",
             "error.message" => "exit: :sad_failure",
             "error.stack_trace" => "** (exit) :sad_failure",
             "error.type" => "exit",
             "log.logger" => "Elixir.LoggerJSON.Formatters.ElasticTest",
             "log.origin" => %{
               "file.line" => _,
               "file.name" => _,
               "function" => _
             }
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
             "message" => "oops!",
             "error.message" => error_message,
             "error.stack_trace" => stacktrace,
             "error.type" => "exit",
             "log.logger" => "Elixir.LoggerJSON.Formatters.ElasticTest",
             "log.origin" => %{
               "file.line" => _,
               "file.name" => _,
               "function" => _
             }
           } = log_entry

    assert stacktrace =~ ~r/\*\* \(EXIT from #PID<\d+\.\d+\.\d+>\) :sad_failure/
    assert error_message =~ ~r/process #PID<\d+\.\d+\.\d+> exit: :sad_failure/
  end

  test "logs reasons in tuple" do
    Logger.metadata(crash_reason: {:socket_closed_unexpectedly, []})

    log_entry =
      capture_log(fn ->
        Logger.debug("oops!")
      end)
      |> decode_or_print_error()

    assert %{
             "message" => "oops!",
             "error.message" => "socket_closed_unexpectedly: []",
             "error.stack_trace" => "** (socket_closed_unexpectedly) []",
             "error.type" => "socket_closed_unexpectedly",
             "log.logger" => "Elixir.LoggerJSON.Formatters.ElasticTest",
             "log.origin" => %{
               "file.line" => _,
               "file.name" => _,
               "function" => _
             }
           } = log_entry
  end

  test "logs http context" do
    conn =
      Plug.Test.conn("GET", "/", "")
      |> Plug.Conn.put_req_header("user-agent", "Mozilla/5.0")
      |> Plug.Conn.put_req_header("referer", "http://www.example2.com/")
      |> Plug.Conn.put_req_header("x-forwarded-for", "")
      |> Plug.Conn.send_resp(200, "Hi!")

    Logger.metadata(conn: conn, duration_us: 1337)

    log_entry =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()

    assert %{
             "client.ip" => "",
             "event.duration" => 1_337_000,
             "http.version" => "HTTP/1.1",
             "http.request.method" => "GET",
             "http.request.referrer" => "http://www.example2.com/",
             "http.response.status_code" => 200,
             "url.path" => "/",
             "user_agent.original" => "Mozilla/5.0"
           } = log_entry
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

    assert %{
             "client.ip" => "",
             "http.version" => "HTTP/1.1",
             "http.request.method" => "PATCH",
             "http.request.referrer" => "http://www.example.com/",
             "http.response.status_code" => 503,
             "url.path" => "/",
             "user_agent.original" => "Mozilla/5.0"
           } = log_entry
  end

  test "logs caught errors" do
    log_entry =
      capture_log(fn ->
        try do
          raise "oops"
        rescue
          e in RuntimeError -> Logger.error("Something went wrong", crash_reason: {e, __STACKTRACE__})
        end
      end)
      |> decode_or_print_error()

    assert %{
             "message" => "Something went wrong",
             "error.message" => "oops",
             "error.type" => "Elixir.RuntimeError",
             "error.stack_trace" => stacktrace,
             "log.level" => "error",
             "log.logger" => "Elixir.LoggerJSON.Formatters.ElasticTest",
             "log.origin" => %{
               "file.name" => origin_file,
               "file.line" => origin_line,
               "function" => origin_function
             }
           } = log_entry

    assert origin_line > 0
    assert String.ends_with?(origin_file, "test/logger_json/formatters/elastic_test.exs")
    assert String.starts_with?(origin_function, "test logs caught errors/1")
    assert String.starts_with?(stacktrace, "** (RuntimeError) oops")
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
             "error.message" => "boom",
             "error.type" => "Elixir.RuntimeError",
             "error.stack_trace" => "** (RuntimeError) boom" <> _,
             "message" => message
           } = log_entry

    assert message =~ ~r/Task #PID<\d+.\d+.\d+> started from #{inspect(test_pid)} terminating/
  end

  test "passing options to encoder" do
    formatter = {Elastic, encoder_opts: [pretty: true]}
    :logger.update_handler_config(:default, :formatter, formatter)

    assert capture_log(fn ->
             Logger.debug("Hello")
           end) =~
             ~r/\n\s{2}"message": "Hello"/
  end

  test "reads metadata from the given application env" do
    Application.put_env(:logger_json, :test_elastic_metadata_key, [:foo])
    formatter = {Elastic, metadata: {:from_application_env, {:logger_json, :test_elastic_metadata_key}}}
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
    Application.put_env(:logger_json, :test_elastic_metadata_key, metadata: [:foo])
    formatter = {Elastic, metadata: {:from_application_env, {:logger_json, :test_elastic_metadata_key}, [:metadata]}}
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
