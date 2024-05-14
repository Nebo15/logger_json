defmodule LoggerJSON.EctoTest do
  use LoggerJSON.Case, async: false
  import LoggerJSON.Ecto
  require Logger

  describe "telemetry_logging_handler/4" do
    test "logs ecto queries received via telemetry event" do
      log =
        capture_log(fn ->
          telemetry_logging_handler(
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
               "metadata" => %{
                 "query" => %{
                   "decode_time_μs" => 0,
                   "execution_time_μs" => 2930,
                   "latency_μs" => 3036,
                   "queue_time_μs" => 106,
                   "repo" => "Repo"
                 }
               },
               "severity" => "info"
             } = decode_or_print_error(log)
    end

    test "allows disabling logging at runtime" do
      log =
        capture_log(fn ->
          telemetry_logging_handler(
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
            {__MODULE__, :ignore_log, [:arg]}
          )

          Logger.flush()
        end)

      assert log == ""
    end
  end

  def ignore_log(_query, _time, :arg), do: false
end
