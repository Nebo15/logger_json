defmodule LoggerJSON.Formatters.DatadogLogger do
  @moduledoc """
  [DataDog](https://www.datadoghq.com) formatter. This will adhere to the
  [default standard attribute list](https://docs.datadoghq.com/logs/processing/attributes_naming_convention/#default-standard-attribute-list)
  as much as possible.

  ## Options

  This formatter has a couple of options to fine tune the logging output for
  your deployed environment.

  ### `hostname`

  By setting the `hostname` value, you can change how the `syslog.hostname` is
  set in logs. In most cases, you can leave this unset and it will use default
  to `:system`, which uses `:inet.gethostname/0` to resolve the value.

  If you are running in an environment where the hostname is not correct, you
  can hard code it by setting `hostname` to a string. In places where the
  hostname is inaccurate but also dynamic (like Kubernetes), you can set
  `hostname` to `:unset` to exclude it entirely. You'll then be relying on
  [`dd-agent`](https://docs.datadoghq.com/agent/) to determine the hostname.

  """
  import Jason.Helpers, only: [json_map: 1]

  alias LoggerJSON.{FormatterUtils, JasonSafeFormatter}

  @behaviour LoggerJSON.Formatter

  @default_opts %{hostname: :system}
  @processed_metadata_keys ~w[pid file line function module application span_id trace_id]a

  @impl true
  def init(formatter_opts \\ %{}) do
    opts = Map.merge(@default_opts, formatter_opts)

    unless is_binary(opts.hostname) or opts.hostname in [:system, :unset] do
      raise ArgumentError,
            "invalid :hostname option for :formatter_opts logger_json backend. " <>
              "Expected :system, :unset, or string, " <> "got: #{inspect(opts.hostname)}"
    end

    opts
  end

  @impl true
  def format_event(level, msg, ts, md, md_keys, formatter_state) do
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
        syslog: syslog(level, ts, formatter_state.hostname)
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

  defp syslog(level, ts, :system) do
    {:ok, hostname} = :inet.gethostname()

    json_map(
      hostname: to_string(hostname),
      severity: Atom.to_string(level),
      timestamp: FormatterUtils.format_timestamp(ts)
    )
  end

  defp syslog(level, ts, :unset) do
    json_map(
      severity: Atom.to_string(level),
      timestamp: FormatterUtils.format_timestamp(ts)
    )
  end

  defp syslog(level, ts, hostname) do
    json_map(
      hostname: hostname,
      severity: Atom.to_string(level),
      timestamp: FormatterUtils.format_timestamp(ts)
    )
  end
end
