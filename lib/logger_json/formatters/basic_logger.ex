defmodule LoggerJSON.Formatters.BasicLogger do
  @moduledoc """
  Basic JSON log formatter with no vendor specific formatting.
  """

  import Jason.Helpers, only: [json_map: 1]

  alias LoggerJSON.{FormatterUtils, JasonSafeFormatter}

  @behaviour LoggerJSON.Formatter

  @processed_metadata_keys ~w[pid file line function module application]a

  @impl true
  def init(_formatter_opts), do: []

  @impl true
  def format_event(level, msg, ts, md, md_keys, _formatter_state) do
    json_map(
      time: FormatterUtils.format_timestamp(ts),
      severity: Atom.to_string(level),
      message: IO.chardata_to_string(msg),
      metadata: format_metadata(md, md_keys)
    )
  end

  defp format_metadata(md, md_keys) do
    md
    |> LoggerJSON.take_metadata(md_keys, @processed_metadata_keys)
    |> FormatterUtils.maybe_put(:error, FormatterUtils.format_process_crash(md))
    |> JasonSafeFormatter.format()
  end
end
