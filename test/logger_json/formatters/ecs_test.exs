defmodule LoggerJSON.Formatters.ECSTest do
  use Logger.Case
  use ExUnitProperties
  alias LoggerJSON.Formatters.ECS
  require Logger

  setup do
    formatter = {ECS, metadata: :all}
    :logger.update_handler_config(:default, :formatter, formatter)
  end

  test "logs an LogEntry of every level" do
    for level <- Logger.levels() do
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
               "log.logger" => "Elixir.LoggerJSON.Formatters.ECSTest",
               "log.origin" => %{
                 "file.name" => origin_file,
                 "file.line" => origin_line,
                 "function" => origin_function
               },
               "message" => ^message
             } = log_entry

      assert {:ok, _, _} = DateTime.from_iso8601(timestamp)
      assert origin_line > 0
      assert String.ends_with?(to_string(origin_file), "test/formatters/ecs_test.exs")
      assert String.starts_with?(to_string(origin_function), "test logs an LogEntry of every level/1")
      assert log_entry["domain"] == nil
    end
  end

  test "logs an LogEntry with a map payload" do
    log =
      capture_log(fn ->
        Logger.debug(%{foo: :bar, fiz: [1, 2, 3, "buz"]})
      end)
      |> decode_or_print_error()

    assert log["fiz"] == [1, 2, 3, "buz"]
    assert log["foo"] == "bar"
  end

  test "logs an LogEntry with a keyword payload" do
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
             "message" => "runtime error",
             "error.message" => "runtime error",
             "error.stack_trace" => stacktrace,
             "error.type" => "Elixir.RuntimeError"
           } = log_entry

    assert stacktrace =~ "** (RuntimeError) runtime error"
    assert stacktrace =~ ~r/test\/formatters\/ecs_test.exs:\d+: anonymous fn\/0/
    assert stacktrace =~ "in LoggerJSON.Formatters.ECSTest.\"test logs exceptions\"/1"
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
             "message" => "oops!",
             "error.message" => "oops!",
             "error.stack_trace" => _,
             "error.type" => "Elixir.LoggerJSON.Formatters.ECSTest.TestException",
             "error.id" => "oops_id",
             "error.code" => 42
           } = log_entry
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
             "log.logger" => "Elixir.LoggerJSON.Formatters.ECSTest",
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
             "log.logger" => "Elixir.LoggerJSON.Formatters.ECSTest",
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
             "error.type" => "EXIT",
             "log.logger" => "Elixir.LoggerJSON.Formatters.ECSTest",
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
             "log.logger" => "Elixir.LoggerJSON.Formatters.ECSTest",
             "log.origin" => %{
               "file.line" => _,
               "file.name" => _,
               "function" => _
             }
           } = log_entry
  end
end
