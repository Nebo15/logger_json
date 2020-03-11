defmodule LoggerJSON.Formatters.BasicLogger do
  @moduledoc """
  Basic JSON log formatter with no vender specific formatting
  """

  alias LoggerJSON.FormatterUtils

  @behaviour LoggerJSON.Formatter

  @processed_metadata_keys ~w[pid file line function module application]a

  @impl true
  def format_event(level, msg, ts, md, md_keys) do
    Map.merge(
      %{
        time: FormatterUtils.format_timestamp(ts),
        severity: Atom.to_string(level),
        message: IO.iodata_to_binary(msg)
      },
      format_metadata(md, md_keys)
    )
  end

  defp format_metadata(md, md_keys) do
    md
    |> LoggerJSON.take_metadata(md_keys, @processed_metadata_keys)
    |> FormatterUtils.maybe_put(:error, FormatterUtils.format_process_crash(md))
  end
end
