defmodule LoggerJSON.Formatters.DataDogLogger do
  @moduledoc """
  DataDog Logger formatter

  See: https://docs.datadoghq.com/logs/log_collection/?tab=http#send-your-application-logs-in-json
  """
  import Jason.Helpers, only: [json_map: 1]
  alias LoggerJSON.{FormatterUtils, JasonSafeFormatter}

  @behaviour LoggerJSON.Formatter

  @processed_metadata_keys ~w[function application]a

  def format_event(level, msg, timestamp, metadata, metadata_keys) do
    Map.merge(
      %{
        timestamp: format_timestamp(timestamp),
        status: level,
        message: IO.iodata_to_binary(msg)
      },
      format_metadata(metadata, metadata_keys)
    )
  rescue
    _ -> "could not format: #{inspect({level, msg, metadata})}"
  end

  defp format_metadata(metadata, metadata_keys) do
    metadata
    |> LoggerJSON.take_metadata(metadata_keys, @processed_metadata_keys)
    |> JasonSafeFormatter.format()
    |> FormatterUtils.maybe_put(:error, format_process_crash(metadata))
  end

  defp format_process_crash(metadata) do
    if crash_reason = Keyword.get(metadata, :crash_reason) do
      initial_call = Keyword.get(metadata, :initial_call)

      case format_crash_reason(crash_reason) do
        {kind, message, stacktrace} ->
          json_map(
            initial_call: format_initial_call(initial_call),
            stack: stacktrace,
            message: message,
            kind: kind
          )

        message ->
          json_map(
            initial_call: format_initial_call(initial_call),
            message: message
          )
      end
    end
  end

  defp format_initial_call(nil), do: nil

  defp format_initial_call({module, function, arity}) do
    Exception.format_mfa(module, function, arity)
  end

  defp format_crash_reason({kind, reason}) when kind in [:throw, :nocatch] do
    {:throw, Exception.format(:throw, reason), nil}
  end

  defp format_crash_reason({:exit, reason}) do
    {:exit, Exception.format(:exit, reason), nil}
  end

  defp format_crash_reason({%kind{} = exception, stacktrace}) do
    {kind, Exception.format_banner(:error, exception), Exception.format_stacktrace(stacktrace)}
  end

  defp format_crash_reason(other) do
    inspect(other)
  end

  defp format_timestamp({{year, month, day}, {hour, min, sec, ms}}) do
    {:ok, datetime} = NaiveDateTime.new(year, month, day, hour, min, sec, {ms * 1000, 3})
    NaiveDateTime.to_iso8601(datetime)
  end
end
