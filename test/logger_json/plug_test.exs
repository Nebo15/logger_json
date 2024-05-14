defmodule LoggerJSON.PlugTest do
  use LoggerJSON.Case, async: false
  import LoggerJSON.Plug
  require Logger

  setup do
    formatter = {LoggerJSON.Formatters.Basic, metadata: :all}
    :logger.update_handler_config(:default, :formatter, formatter)
  end

  describe "attach/3" do
    test "attaches a telemetry handler" do
      assert attach(
               "logger-json-phoenix-requests",
               [:phoenix, :endpoint, :stop],
               :info
             ) == :ok

      assert [
               %{
                 function: _function,
                 id: "logger-json-phoenix-requests",
                 config: :info,
                 event_name: [:phoenix, :endpoint, :stop]
               }
             ] = :telemetry.list_handlers([:phoenix, :endpoint, :stop])
    end
  end

  describe "telemetry_logging_handler/4" do
    test "logs request latency and metadata" do
      conn = Plug.Test.conn(:get, "/") |> Plug.Conn.put_status(200)

      log =
        capture_log(fn ->
          telemetry_logging_handler(
            [:phoenix, :endpoint, :stop],
            %{duration: 500_000},
            %{conn: conn},
            :info
          )

          Logger.flush()
        end)

      assert %{
               "message" => "GET / [Sent 200 in 500µs]",
               "metadata" => %{"duration_μs" => 500},
               "request" => %{
                 "client" => %{"ip" => "127.0.0.1", "user_agent" => nil},
                 "connection" => %{"method" => "GET", "path" => "/", "protocol" => "HTTP/1.1", "status" => 200}
               }
             } = decode_or_print_error(log)
    end

    test "logs unsent connections" do
      conn = Plug.Test.conn(:get, "/")

      log =
        capture_log(fn ->
          telemetry_logging_handler(
            [:phoenix, :endpoint, :stop],
            %{duration: 500_000},
            %{conn: conn},
            :info
          )

          Logger.flush()
        end)

      assert %{
               "message" => "GET / [Sent in 500µs]",
               "metadata" => %{"duration_μs" => 500},
               "request" => %{
                 "client" => %{"ip" => "127.0.0.1", "user_agent" => nil},
                 "connection" => %{"method" => "GET", "path" => "/", "protocol" => "HTTP/1.1", "status" => nil}
               }
             } = decode_or_print_error(log)
    end

    test "logs chunked responses" do
      conn = %{Plug.Test.conn(:get, "/") | state: :set_chunked}

      log =
        capture_log(fn ->
          telemetry_logging_handler(
            [:phoenix, :endpoint, :stop],
            %{duration: 500_000},
            %{conn: conn},
            :info
          )

          Logger.flush()
        end)

      assert %{
               "message" => "GET / [Chunked in 500µs]",
               "metadata" => %{"duration_μs" => 500},
               "request" => %{
                 "client" => %{"ip" => "127.0.0.1", "user_agent" => nil},
                 "connection" => %{"method" => "GET", "path" => "/", "protocol" => "HTTP/1.1", "status" => nil}
               }
             } = decode_or_print_error(log)
    end

    test "logs long-running responses" do
      conn = %{Plug.Test.conn(:get, "/") | state: :set_chunked}

      log =
        capture_log(fn ->
          telemetry_logging_handler(
            [:phoenix, :endpoint, :stop],
            %{duration: 500_000_000},
            %{conn: conn},
            :info
          )

          Logger.flush()
        end)

      assert %{"message" => "GET / [Chunked in 500ms]"} = decode_or_print_error(log)
    end

    test "allows disabling logging at runtime" do
      conn = Plug.Test.conn(:get, "/")

      log =
        capture_log(fn ->
          telemetry_logging_handler(
            [:phoenix, :endpoint, :stop],
            %{duration: 5000},
            %{conn: conn},
            {__MODULE__, :ignore_log, [:arg]}
          )

          Logger.flush()
        end)

      assert log == ""
    end
  end

  def ignore_log(%Plug.Conn{}, :arg), do: false
end
