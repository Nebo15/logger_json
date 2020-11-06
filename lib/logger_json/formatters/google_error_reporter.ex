defmodule LoggerJSON.Formatters.GoogleErrorReporter do
  require Logger
  @googleErrorType "type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent"

  def report(error, stacktrace, metadata \\ []) do
    [format_error(error, stacktrace) | Enum.map(stacktrace, &format_line/1)]
    |> Enum.filter(& &1)
    |> Enum.join("\n")
    |> Logger.error(Keyword.merge(build_metadata(), metadata))
  end

  defp format_error(error, stacktrace) do
    normalized = Exception.normalize(:error, error, stacktrace)
    error_name = to_string(normalized.__struct__)
    "#{error_name}: #{Exception.message(normalized)}"
  end

  defp format_line({module, function, arity, [file: file, line: line]}) do
    "\t#{file}:#{line}:in `#{module}.#{function}/#{arity}'"
  end

  defp format_line({_, _, _, []}), do: nil

  defp build_metadata() do
    ["@type": @googleErrorType]
    |> with_service_context()
  end

  defp with_service_context(metadata) do
    if service_context = config()[:service_context] do
      Keyword.merge(metadata, serviceContext: service_context)
    else
      metadata
    end
  end

  defp config do
    Application.get_env(:logger_json, :google_error_reporter, [])
  end
end
