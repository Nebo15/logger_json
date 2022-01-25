defmodule LoggerJSON.Formatters.DatadogLogger do
  @moduledoc """
  DataDog formatter.

  Adhere to the
  [default standard attribute list](https://docs.datadoghq.com/logs/processing/attributes_naming_convention/#default-standard-attribute-list).
  """
  import Jason.Helpers, only: [json_map: 1]

  alias LoggerJSON.{FormatterUtils, JasonSafeFormatter}

  @behaviour LoggerJSON.Formatter

  @processed_metadata_keys ~w[pid file line function module application span_id trace_id]a

  def format_event(level, msg, ts, md, md_keys) do
    Map.merge(
      %{
        logger:
          json_map(
            thread_name: inspect(Keyword.get(md, :pid)),
            method_name: method_name(md),
            file_name: Keyword.get(md, :file),
            line: Keyword.get(md, :line)
          ),
        message: IO.chardata_to_string(msg),
        syslog:
          json_map(
            hostname: node_hostname(),
            severity: Atom.to_string(level),
            timestamp: FormatterUtils.format_timestamp(ts)
          )
      },
      format_metadata(md, md_keys)
    )
  end

  defp format_metadata(md, md_keys) do
    LoggerJSON.take_metadata(md, md_keys, @processed_metadata_keys)
    |> convert_tracing_keys(md)
    |> JasonSafeFormatter.format()
    |> FormatterUtils.maybe_put(:error, FormatterUtils.format_process_crash(md))
  end

  # To connect logs and traces, span_id and trace_id keys are respectively dd.span_id and dd.trace_id
  # https://docs.datadoghq.com/tracing/faq/why-cant-i-see-my-correlated-logs-in-the-trace-id-panel/?tab=jsonlogs
  defp convert_tracing_keys(output, md) do
    Enum.reduce([:trace_id, :span_id], output, fn key, acc ->
      if Keyword.has_key?(md, key) do
        dd_key = "dd." <> Atom.to_string(key)
        Map.merge(acc, %{dd_key => Keyword.get(md, key)})
      else
        acc
      end
    end)
  end

  defp method_name(metadata) do
    function = Keyword.get(metadata, :function)
    module = Keyword.get(metadata, :module)

    FormatterUtils.format_function(module, function)
  end

  defp node_hostname do
    {:ok, hostname} = :inet.gethostname()
    to_string(hostname)
  end
end
