defmodule LoggerJSON.Formatter.Message do
  @moduledoc false

  # crash
  def format_message({:string, message}, %{crash_reason: crash_reason}, %{crash: crash_fmt}) do
    crash_fmt.(message, crash_reason)
  end

  # binary
  def format_message({:string, message}, _meta, %{binary: binary_fmt}) do
    binary_fmt.(message)
  end

  # OTP report or structured logging data
  def format_message(
        {:report, data},
        %{report_cb: callback} = meta,
        %{binary: binary_fmt, structured: structured_fmt} = formatters
      ) do
    cond do
      is_function(callback, 1) and callback != (&:logger.format_otp_report/1) ->
        format_message(callback.(data), meta, formatters)

      is_function(callback, 2) ->
        callback.(data, %{depth: :unlimited, chars_limit: :unlimited, single_line: false})
        |> binary_fmt.()

      true ->
        structured_fmt.(data)
    end
  end

  def format_message({:report, data}, _meta, %{structured: structured_fmt}) do
    structured_fmt.(data)
  end

  def format_message({format, args}, _meta, %{binary: binary_fmt}) do
    format
    |> Logger.Utils.scan_inspect(args, :infinity)
    |> :io_lib.build_text()
    |> binary_fmt.()
  end
end
