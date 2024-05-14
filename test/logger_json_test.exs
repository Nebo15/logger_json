defmodule LoggerJSONTest do
  use ExUnit.Case

  describe "configure_log_level_from_env/1" do
    test "configures log level from environment variable" do
      System.put_env("LOGGER_JSON_TEST_LOG_LEVEL", "warning")
      assert LoggerJSON.configure_log_level_from_env!("LOGGER_JSON_TEST_LOG_LEVEL") == :ok
      assert Logger.level() == :warning
    end
  end

  describe "configure_log_level/1" do
    test "configures log level" do
      assert LoggerJSON.configure_log_level!("debug") == :ok
      assert Logger.level() == :debug

      assert LoggerJSON.configure_log_level!(:info) == :ok
      assert Logger.level() == :info
    end

    test "raises on invalid log level" do
      message = "Log level should be one of 'debug', 'info', 'warn', 'error' values, got: :invalid"

      assert_raise ArgumentError, message, fn ->
        LoggerJSON.configure_log_level!(:invalid)
      end
    end
  end
end
