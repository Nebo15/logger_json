defmodule LoggerJSON.PlugTest do
  use LoggerJSON.Case, async: false
  import LoggerJSON.Plug
  require Logger

  setup do
    formatter = {LoggerJSON.Formatters.Basic, metadata: :all}
    :logger.update_handler_config(:default, :formatter, formatter)
  end

  describe "telemetry_logging_handler/4" do
    test "logs request latency and metadata" do
      conn = Plug.Test.conn(:get, "/")

      log =
        capture_log(fn ->
          telemetry_logging_handler(
            [:phoenix, :endpoint, :stop],
            %{duration: 5000},
            %{conn: conn},
            :info
          )

          Logger.flush()
        end)

      assert %{
               "message" => "",
               "metadata" => %{"duration_μs" => 5},
               "request" => %{
                 "client" => %{"ip" => "127.0.0.1", "user_agent" => nil},
                 "connection" => %{"method" => "GET", "path" => "/", "protocol" => "HTTP/1.1", "status" => nil}
               }
             } = decode_or_print_error(log)
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
