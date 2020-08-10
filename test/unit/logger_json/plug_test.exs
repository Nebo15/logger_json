defmodule LoggerJSON.PlugTest do
  use Logger.Case, async: false
  use Plug.Test
  import ExUnit.CaptureIO
  require Logger

  defmodule MyPlug do
    use Plug.Builder

    plug(LoggerJSON.Plug)
    plug(:passthrough)

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end
  end

  defmodule MyPlugWithExtraAttributes do
    use Plug.Builder

    plug(LoggerJSON.Plug, extra_attributes_fn: &__MODULE__.add_meta/1)
    plug(:passthrough)

    defp passthrough(conn, _) do
      Plug.Conn.send_resp(conn, 200, "Passthrough")
    end

    import Plug.Conn
    import Jason.Helpers, only: [json_map: 1]

    @spec add_meta(%Plug.Conn{}) :: Keyword.t()
    def add_meta(conn) do
      [
        sample_key: "test-helper",
        meta: json_map(x_request_id: get_req_header(conn, "x-request-id") |> List.last())
      ]
    end
  end

  setup do
    :ok =
      Logger.configure_backend(
        LoggerJSON,
        device: :standard_error,
        level: nil,
        metadata: :all,
        json_encoder: Jason,
        on_init: :disabled,
        formatter: LoggerJSON.Formatters.GoogleCloudLogger
      )
  end

  test "logs request information" do
    Logger.metadata(request_id: "request_id")

    log =
      capture_io(:standard_error, fn ->
        call(conn(:get, "/"))
        Logger.flush()
      end)

    assert %{
             "message" => "",
             "httpRequest" => %{
               "latency" => latency,
               "referer" => nil,
               "remoteIp" => "127.0.0.1",
               "requestMethod" => "GET",
               "requestPath" => "/",
               "requestUrl" => "http://www.example.com/",
               "status" => 200,
               "userAgent" => nil
             },
             "logging.googleapis.com/operation" => %{"id" => "request_id"},
             "severity" => "INFO"
           } = Jason.decode!(log)

    assert {latency_number, "s"} = Float.parse(latency)
    assert latency_number > 0

    conn = %{conn(:get, "/hello/world") | private: %{phoenix_controller: MyController, phoenix_action: :foo}}

    log =
      capture_io(:standard_error, fn ->
        call(conn)
        Logger.flush()
      end)

    assert %{
             "httpRequest" => %{
               "requestUrl" => "http://www.example.com/hello/world"
             },
             "phoenix" => %{
               "action" => "foo",
               "controller" => "Elixir.MyController"
             }
           } = Jason.decode!(log)
  end

  test "takes values from request headers" do
    request_id = Ecto.UUID.generate()

    conn =
      :get
      |> conn("/")
      |> Plug.Conn.put_resp_header("x-request-id", request_id)
      |> Plug.Conn.put_req_header("user-agent", "chrome")
      |> Plug.Conn.put_req_header("referer", "http://google.com")
      |> Plug.Conn.put_req_header("x-forwarded-for", "127.0.0.10")
      |> Plug.Conn.put_req_header("x-api-version", "2017-01-01")

    log =
      capture_io(:standard_error, fn ->
        call(conn)
        Logger.flush()
      end)

    assert %{
             "httpRequest" => %{
               "referer" => "http://google.com",
               "remoteIp" => "127.0.0.10",
               "userAgent" => "chrome"
             }
           } = Jason.decode!(log)
  end

  test "has extra_attributes_fn configured" do
    request_id = Ecto.UUID.generate()

    conn =
      :get
      |> conn("/")
      |> Plug.Conn.put_resp_header("x-request-id", request_id)
      |> Plug.Conn.put_req_header("x-request-id", request_id)
      |> Plug.Conn.put_req_header("user-agent", "chrome")
      |> Plug.Conn.put_req_header("referer", "http://google.com")
      |> Plug.Conn.put_req_header("x-forwarded-for", "127.0.0.10")
      |> Plug.Conn.put_req_header("x-api-version", "2017-01-01")

    log =
      capture_io(:standard_error, fn ->
        call_extra_attributes(conn)
        Logger.flush()
      end)

    log_map = Jason.decode!(log)

    assert %{
             "httpRequest" => %{
               "referer" => "http://google.com",
               "remoteIp" => "127.0.0.10",
               "userAgent" => "chrome"
             },
             "sample_key" => "test-helper",
             "meta" => %{"x_request_id" => request_id}
           } = log_map

    assert Map.has_key?(log_map, "sample_key")
    assert Map.has_key?(log_map, "meta")
    assert Map.has_key?(log_map["meta"], "x_request_id")

    assert %{
             "x_request_id" => request_id
           } == log_map["meta"]
  end

  test "invalid extra_attributes_fn configuration" do
    assert %ArgumentError{message: _, __exception__: true} =
             catch_error(
               defmodule MyPlugWithInvalidExtraAttributes do
                 use Plug.Builder
                 plug(LoggerJSON.Plug, extra_attributes_fn: "")
               end
             )
  end

  defp call(conn) do
    MyPlug.call(conn, [])
  end

  defp call_extra_attributes(conn) do
    MyPlugWithExtraAttributes.call(conn, [])
  end
end
