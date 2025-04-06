defmodule LoggerJSON.EctoTest do
  use LoggerJSON.Case, async: false
  import LoggerJSON.Ecto
  require Logger

  setup do
    formatter = LoggerJSON.Formatters.Basic.new(metadata: :all)
    :logger.update_handler_config(:default, :formatter, formatter)
  end

  describe "attach/3" do
    test "attaches a telemetry handler" do
      assert attach(
               "logger-json-queries",
               [:my_app, :repo, :query],
               :info
             ) == :ok

      assert [
               %{
                 function: _function,
                 id: "logger-json-queries",
                 config: :info,
                 event_name: [:my_app, :repo, :query]
               }
             ] = :telemetry.list_handlers([:my_app, :repo, :query])
    end
  end

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
                   "decode_time_us" => 0,
                   "execution_time_us" => 2930,
                   "latency_us" => 3036,
                   "queue_time_us" => 106,
                   "repo" => "Repo"
                 }
               }
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
