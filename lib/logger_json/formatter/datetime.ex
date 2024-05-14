defmodule LoggerJSON.Formatter.DateTime do
  @moduledoc false

  @doc """
  Returns either a `time` taken from metadata or current time in RFC3339 UTC "Zulu" format.
  """
  def utc_time(%{time: time}) when is_integer(time) and time >= 0 do
    system_time_to_rfc3339(time)
  end

  def utc_time(_meta) do
    :os.system_time(:microsecond)
    |> system_time_to_rfc3339()
  end

  defp system_time_to_rfc3339(system_time) do
    micro = rem(system_time, 1_000_000)

    {date, {hours, minutes, seconds}} = :calendar.system_time_to_universal_time(system_time, :microsecond)

    [format_date(date), ?T, format_time({hours, minutes, seconds, div(micro, 1000)}), ?Z]
    |> IO.iodata_to_binary()
  end

  defp format_time({hh, mi, ss, ms}) do
    [pad2(hh), ?:, pad2(mi), ?:, pad2(ss), ?., pad3(ms)]
  end

  defp format_date({yy, mm, dd}) do
    [Integer.to_string(yy), ?-, pad2(mm), ?-, pad2(dd)]
  end

  defp pad3(int) when int < 10, do: [?0, ?0, Integer.to_string(int)]
  defp pad3(int) when int < 100, do: [?0, Integer.to_string(int)]
  defp pad3(int), do: Integer.to_string(int)

  defp pad2(int) when int < 10, do: [?0, Integer.to_string(int)]
  defp pad2(int), do: Integer.to_string(int)
end
