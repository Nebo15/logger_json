defmodule LoggerJSON.Phoenix.LoggerTest do
  use Logger.Case, async: false
  use Plug.Test

  setup do
    LoggerJSON.Phoenix.Logger.install(metadata_formatter: LoggerJSON.Plug.MetadataFormatters.DatadogLogger)

    on_exit(fn ->
      :telemetry.detach([:phoenix, :endpoint, :stop])
    end)

    telemetry_opts = Plug.Telemetry.init(event_prefix: [:phoenix, :endpoint])
    :ok = Logger.reset_metadata([])
    request_id = Ecto.UUID.generate()

    conn =
      conn(:get, "/")
      |> Plug.Conn.put_resp_header("x-request-id", request_id)
      |> Plug.Conn.put_req_header("user-agent", "chrome")
      |> Plug.Conn.put_req_header("referer", "http://google.com")
      |> Plug.Conn.put_req_header("x-forwarded-for", "127.0.0.10")
      |> Plug.Conn.put_req_header("x-api-version", "2017-01-01")

    {:ok, conn: conn, telemetry_opts: telemetry_opts}
  end

  describe "basic logger formatter" do
    setup do
      Logger.configure_backend(
        LoggerJSON,
        device: :user,
        level: :info,
        metadata: :all,
        json_encoder: Jason,
        on_init: :disabled,
        formatter: LoggerJSON.Formatters.BasicLogger,
        formatter_state: %{}
      )

      :ok = Logger.reset_metadata([])
    end

    test "w/ default datadog metadata", %{conn: conn, telemetry_opts: telemetry_opts} do
      assert raw_log =
               capture_log(:info, fn ->
                 Plug.Telemetry.call(conn, telemetry_opts) |> Plug.Conn.send_resp(200, "{}")
               end)

      assert is_binary(raw_log)
      assert log = Jason.decode!(raw_log)
      assert log["message"] =~ "GET / returns 200 in"
      assert log["severity"] == "info"
      assert log["time"]
      assert log["metadata"]["duration"]

      assert %{
               "method" => "GET",
               "referer" => "http://google.com",
               "status_code" => 200,
               "url" => "http://www.example.com/",
               "url_details" => %{
                 "host" => "www.example.com",
                 "path" => "/",
                 "port" => 80,
                 "queryString" => "",
                 "scheme" => "http"
               },
               "useragent" => "chrome"
             } = log["metadata"]["http"]
    end
  end

  describe "datadog logger formatter" do
    setup do
      Logger.configure_backend(
        LoggerJSON,
        device: :user,
        level: :info,
        metadata: :all,
        json_encoder: Jason,
        on_init: :disabled,
        formatter: LoggerJSON.Formatters.DatadogLogger,
        formatter_state: %{}
      )

      :ok = Logger.reset_metadata([])
    end

    test "w/ default datadog metadata", %{conn: conn, telemetry_opts: telemetry_opts} do
      assert raw_log =
               capture_log(:info, fn ->
                 Plug.Telemetry.call(conn, telemetry_opts) |> Plug.Conn.send_resp(200, "{}")
               end)

      assert is_binary(raw_log)
      assert log = Jason.decode!(raw_log)
      assert log["message"] =~ "GET / returns 200 in"
      assert log["syslog"]["severity"] == "info"
      assert log["network"] == %{"client" => %{"ip" => "127.0.0.10"}}

      assert %{
               "method" => "GET",
               "referer" => "http://google.com",
               "status_code" => 200,
               "url" => "http://www.example.com/",
               "url_details" => %{
                 "host" => "www.example.com",
                 "path" => "/",
                 "port" => 80,
                 "queryString" => "",
                 "scheme" => "http"
               },
               "useragent" => "chrome"
             } = log["http"]
    end
  end
end
