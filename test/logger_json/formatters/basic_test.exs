defmodule LoggerJSON.Formatters.BasicTest do
  use LoggerJSON.Case
  use ExUnitProperties
  alias LoggerJSON.Formatters.Basic
  require Logger

  setup do
    formatter = {Basic, metadata: :all}
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

  test "logs message of a given level" do
    for level <- [:error, :info, :debug, :emergency, :alert, :critical, :warning, :notice] do
      log =
        capture_log(level, fn ->
          Logger.log(level, "Hello")
        end)
        |> decode_or_print_error()

      level_string = to_string(level)

      assert %{
               "message" => "Hello",
               "metadata" => %{"domain" => ["elixir"]},
               "severity" => ^level_string,
               "time" => _
             } = log
    end
  end

  test "logs message with a map payload" do
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

  test "logs message with a keyword payload" do
    log =
      capture_log(fn ->
        Logger.debug(a: {0, false})
      end)
      |> decode_or_print_error()

    assert log["message"] == %{
             "a" => [0, false]
           }
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

    assert log["span"] == "bff20904aa5883a6"
    assert log["trace"] == "294740ce41cc9f202dedb563db123532"
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

    assert log["span"] == "bff20904aa5883a6"
    assert log["trace"] == "294740ce41cc9f202dedb563db123532"
  end

  test "logs file, line and mfa as metadata" do
    metadata =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()
      |> Map.get("metadata")

    assert metadata |> Map.get("file") |> to_string() =~ "logger_json/formatters/basic_test.exs"
    assert metadata |> Map.get("line") |> is_integer()

    assert metadata["mfa"] === "Elixir.LoggerJSON.Formatters.BasicTest.test logs file, line and mfa as metadata/1"
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
             "metadata" => %{
               "atom" => "atom",
               "binary" => "binary",
               "date" => _,
               "domain" => ["elixir"],
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
             }
           } = log

    formatter = {Basic, metadata: {:all_except, [:struct]}}
    :logger.update_handler_config(:default, :formatter, formatter)

    log =
      capture_log(fn ->
        Logger.debug("Hello", float: 3.14)
      end)
      |> decode_or_print_error()

    assert %{
             "metadata" => %{
               "atom" => "atom",
               "binary" => "binary",
               "date" => _,
               "domain" => ["elixir"],
               "list" => [1, 2, 3],
               "map" => %{"foo" => "bar"},
               "node" => "nonode@nohost",
               "ref" => _ref,
               "float" => 3.14
             }
           } = log

    formatter = {Basic, metadata: [:node]}
    :logger.update_handler_config(:default, :formatter, formatter)

    log =
      capture_log(fn ->
        Logger.debug("Hello", float: 3.14)
      end)
      |> decode_or_print_error()

    assert log["metadata"] == %{"node" => "nonode@nohost"}
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

    assert log["message"] =~ "Process #PID<"
    assert log["message"] =~ "> raised an exception"
    assert log["message"] =~ "RuntimeError"
  end

  test "logs http context" do
    conn =
      Plug.Test.conn("GET", "/", "")
      |> Plug.Conn.put_req_header("user-agent", "Mozilla/5.0")
      |> Plug.Conn.put_req_header("referer", "http://www.example2.com/")
      |> Plug.Conn.put_req_header("x-forwarded-for", "127.0.0.1,200.111.222.111")
      |> Plug.Conn.send_resp(200, "Hi!")

    Logger.metadata(conn: conn)

    log =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()

    assert log["request"] == %{
             "client" => %{
               "ip" => "127.0.0.1",
               "user_agent" => "Mozilla/5.0"
             },
             "connection" => %{
               "method" => "GET",
               "path" => "/",
               "protocol" => "HTTP/1.1",
               "status" => 200
             }
           }
  end

  test "passing options to encoder" do
    formatter = {Basic, encoder_opts: [pretty: true]}
    :logger.update_handler_config(:default, :formatter, formatter)

    assert capture_log(fn ->
             Logger.debug("Hello")
           end) =~
             ~r/\n\s{2}"message": "Hello"/
  end

  test "reads metadata from the given application env" do
    Application.put_env(:logger_json, :test_basic_metadata_key, [:foo])
    formatter = {Basic, metadata: {:from_application_env, {:logger_json, :test_basic_metadata_key}}}
    :logger.update_handler_config(:default, :formatter, formatter)

    Logger.metadata(foo: "foo")

    log =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()

    assert %{
             "metadata" => %{
               "foo" => "foo"
             }
           } = log
  end

  test "reads metadata from the given application env at given path" do
    Application.put_env(:logger_json, :test_basic_metadata_key, metadata: [:foo])
    formatter = {Basic, metadata: {:from_application_env, {:logger_json, :test_basic_metadata_key}, [:metadata]}}
    :logger.update_handler_config(:default, :formatter, formatter)

    Logger.metadata(foo: "foo")

    log =
      capture_log(fn ->
        Logger.debug("Hello")
      end)
      |> decode_or_print_error()

    assert %{
             "metadata" => %{
               "foo" => "foo"
             }
           } = log
  end
end
