defmodule LoggerJSON.Formatter.MessageTest do
  use ExUnit.Case, async: true
  import LoggerJSON.Formatter.Message

  describe "format_message/3" do
    setup do
      # Define mock formatters
      binary_fmt = fn data -> "Binary: #{data}" end
      structured_fmt = fn data -> "Structured: #{inspect(data)}" end
      crash_fmt = fn message, reason -> "Crash: #{message} - #{reason}" end

      {:ok, formatters: %{binary: binary_fmt, structured: structured_fmt, crash: crash_fmt}}
    end

    test "formats crash messages correctly", %{formatters: formatters} do
      message = {:string, "Error occurred"}
      meta = %{crash_reason: "something went wrong"}
      assert format_message(message, meta, %{crash: formatters.crash}) == "Crash: Error occurred - something went wrong"
    end

    test "formats binary messages correctly", %{formatters: formatters} do
      message = {:string, "Hello, world!"}
      meta = %{}
      assert format_message(message, meta, %{binary: formatters.binary}) == "Binary: Hello, world!"
    end

    test "formats structured messages without callback correctly", %{formatters: formatters} do
      message = {:report, %{id: 1, content: "Report data"}}
      meta = %{}

      assert format_message(message, meta, %{structured: formatters.structured}) ==
               "Structured: %{id: 1, content: \"Report data\"}"
    end

    test "formats reports with custom callbacks altering the data", %{formatters: formatters} do
      callback = fn data -> {:string, "Altered: #{data.content}"} end
      message = {:report, %{content: "Original"}}
      meta = %{report_cb: callback}
      assert format_message(message, meta, formatters) == "Binary: Altered: Original"
    end

    test "formats reports with callbacks for binary formatting", %{formatters: formatters} do
      callback = fn data, _opts -> "Processed: #{data.content}" end
      message = {:report, %{content: "Needs processing"}}
      meta = %{report_cb: callback}

      assert format_message(message, meta, %{binary: formatters.binary, structured: formatters.structured}) ==
               "Binary: Processed: Needs processing"
    end

    test "formats report with default behavior", %{formatters: formatters} do
      message = {:report, %{id: 2, content: "Another report"}}
      meta = %{report_cb: &:logger.format_otp_report/1}
      assert format_message(message, meta, formatters) == "Structured: %{id: 2, content: \"Another report\"}"
    end

    test "formats general message using Logger.Utils.scan_inspect", %{formatters: formatters} do
      message = {:string, "Message"}
      meta = %{}
      assert format_message(message, meta, %{binary: formatters.binary}) == "Binary: Message"
    end

    test "formats reports with complex callback and binary formatting", %{formatters: formatters} do
      message = {~c"~p", [1]}
      meta = %{report_cb: nil}

      assert format_message(message, meta, %{binary: formatters.binary, structured: formatters.structured}) ==
               "Binary: 1"
    end
  end
end
