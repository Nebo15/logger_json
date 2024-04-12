defmodule LoggerJSON.Formatters.DatadogTest do
  use Logger.Case
  use ExUnitProperties
  alias LoggerJSON.Formatters.Datadog
  require Logger

  setup do
    formatter = {Datadog, metadata: :all}
    :logger.update_handler_config(:default, :formatter, formatter)
  end

  property "allows to log any binary messages" do
    check all message <- StreamData.binary() do
      assert capture_log(fn ->
               Logger.debug(message)
             end)
             |> decode_or_print_error()
             |> Map.has_key?("message")
    end
  end

  property "allows to log any structured messages" do
    check all message <- StreamData.map_of(StreamData.atom(:alphanumeric), StreamData.term()) do
      assert capture_log(fn ->
               Logger.debug(message)
             end)
             |> decode_or_print_error()
             |> Map.has_key?("message")
    end

    check all message <- StreamData.keyword_of(StreamData.term()) do
      assert capture_log(fn ->
               Logger.debug(message)
             end)
             |> decode_or_print_error()
             |> Map.has_key?("message")
    end
  end

  test "logs an LogEntry of a given level" do
    for level <- Logger.levels() do
      log =
        capture_log(level, fn ->
          Logger.log(level, "Hello")
        end)
        |> decode_or_print_error()

      level_string = to_string(level)

      assert %{
               "message" => "Hello",
               "domain" => ["elixir"],
               "syslog" => %{"hostname" => _hostname, "severity" => ^level_string, "timestamp" => _time}
             } = log
    end
  end

  test "logs an LogEntry with a map payload" do
    log =
      capture_log(fn ->
        Logger.debug(%{foo: :bar, fiz: [1, 2, 3, "buz"]})
      end)
      |> decode_or_print_error()

    assert log["message"] == %{
             "fiz" => [1, 2, 3, "buz"],
             "foo" => "bar"
           }
  end

  test "logs an LogEntry with a keyword payload" do
    log =
      capture_log(fn ->
        Logger.debug(a: {0, false})
      end)
      |> decode_or_print_error()

    assert log["message"] == %{
             "a" => [0, false]
           }
  end

  test "logs hostname" do
    # uses the hostname of the machine by default
    log =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()

    assert log["syslog"]["hostname"] == :inet.gethostname() |> elem(1) |> IO.chardata_to_string()

    # static value
    formatter = {Datadog, hostname: "foo.bar1"}
    :logger.update_handler_config(:default, :formatter, formatter)

    log =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()

    assert log["syslog"]["hostname"] == "foo.bar1"

    # unset value
    formatter = {Datadog, hostname: :unset}
    :logger.update_handler_config(:default, :formatter, formatter)

    log =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()

    refute Map.has_key?(log["syslog"], "hostname")
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

    assert log["dd.span_id"] == "13831127321250661286"
    assert log["dd.trace_id"] == "3309500741668975922"
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

    assert log["dd.span_id"] == "bff20904aa5883a6"
    assert log["dd.trace_id"] == "294740ce41cc9f202dedb563db123532"
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

    log =
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
           } = log
  end

  test "logs exceptions" do
    log =
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
             "error" => %{
               "message" => message,
               "stack" => stacktrace
             },
             "syslog" => %{
               "hostname" => _,
               "severity" => "error",
               "timestamp" => _
             }
           } = log

    assert message =~ "Process #PID<"
    assert message =~ "> raised an exception"
    assert message =~ "** (RuntimeError) runtime error"
    assert stacktrace =~ "test/"
  end

  test "logs http context" do
    conn =
      Plug.Test.conn("GET", "/", "")
      |> Plug.Conn.put_req_header("user-agent", "Mozilla/5.0")
      |> Plug.Conn.put_req_header("referer", "http://www.example2.com/")
      |> Plug.Conn.put_req_header("x-forwarded-for", "127.0.0.1")
      |> Plug.Conn.send_resp(200, "Hi!")

    Logger.metadata(conn: conn)

    log =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()

    assert log["network"] == %{"client" => %{"ip" => "127.0.0.1"}}

    assert log["http"] == %{
             "referer" => "http://www.example2.com/",
             "method" => "GET",
             "request_id" => nil,
             "status_code" => 200,
             "url" => "http://www.example.com/",
             "url_details" => %{
               "host" => "www.example.com",
               "path" => "/",
               "port" => 80,
               "queryString" => "",
               "scheme" => "http"
             },
             "useragent" => "Mozilla/5.0"
           }
  end
end
