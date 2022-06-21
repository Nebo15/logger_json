defmodule LoggerJSON.EctoTest do
  use Logger.Case, async: false
  import ExUnit.CaptureIO
  require Logger

  setup do
    :ok =
      Logger.configure_backend(
        LoggerJSON,
        device: :user,
        level: nil,
        metadata: [],
        json_encoder: Jason,
        on_init: :disabled,
        formatter: LoggerJSON.Formatters.GoogleCloudLogger,
        formatter_state: %{}
      )

    diff = :erlang.convert_time_unit(1, :microsecond, :native)

    entry = %{
      query: fn -> "done" end,
      result: {:ok, []},
      params: [1, 2, 3, %Ecto.Query.Tagged{value: 1}],
      query_time: 2100 * diff,
      decode_time: 500 * diff,
      queue_time: 100 * diff,
      source: "test"
    }

    %{log_entry: entry}
  end

  test "logs ecto queries", %{log_entry: entry} do
    Logger.configure_backend(LoggerJSON, device: :standard_error, metadata: :all)

    log =
      capture_io(:standard_error, fn ->
        LoggerJSON.Ecto.log(entry)
        Logger.flush()
      end)

    assert %{
             "message" => "done",
             "query" => %{
               "decode_time_μs" => 500,
               "latency_μs" => 2700,
               "execution_time_μs" => 2100,
               "queue_time_μs" => 100
             }
           } = Jason.decode!(log)
  end

  test "logs ecto queries with debug level", %{log_entry: entry} do
    Logger.configure_backend(LoggerJSON, device: :standard_error, metadata: :all)

    log =
      capture_io(:standard_error, fn ->
        LoggerJSON.Ecto.log(entry, :debug)
        Logger.flush()
      end)

    assert %{
             "message" => "done",
             "query" => %{
               "decode_time_μs" => 500,
               "latency_μs" => 2700,
               "execution_time_μs" => 2100,
               "queue_time_μs" => 100
             }
           } = Jason.decode!(log)
  end

  test "logs ecto queries received via telemetry event" do
    Logger.configure_backend(LoggerJSON, device: :standard_error, metadata: :all)

    log =
      capture_io(:standard_error, fn ->
        LoggerJSON.Ecto.telemetry_logging_handler(
          [:repo, :query],
          %{query_time: 2_930_000, queue_time: 106_000, total_time: 3_036_000},
          %{
            params: [],
            query: "begin",
            repo: Repo,
            result:
              {:ok,
               %{
                 columns: nil,
                 command: :savepoint,
                 connection_id: 26925,
                 messages: [],
                 num_rows: nil,
                 rows: nil
               }},
            source: nil,
            type: :ecto_sql_query
          },
          :info
        )

        Logger.flush()
      end)

    assert %{
             "message" => "begin",
             "query" => %{
               "latency_μs" => 3036,
               "execution_time_μs" => 2930,
               "queue_time_μs" => 106,
               "repo" => "Repo"
             }
           } = Jason.decode!(log)
  end
end
