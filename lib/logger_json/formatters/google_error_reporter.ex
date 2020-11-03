defmodule LoggerJSON.Formatters.GoogleErrorReporter do
  require Logger
  @googleErrorType "type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent"

  def report(error, stacktrace) do
    [format_error(error, stacktrace) | Enum.map(stacktrace, &format_line/1)]
    |> Enum.join("\n")
    |> Logger.error(["@type": @googleErrorType])
  end

  defp format_error(error, stacktrace) do
    normalized = Exception.normalize(:error, error, stacktrace)
    error_name = to_string(normalized.__struct__)
    "#{error_name}: #{Exception.message(normalized)}"
  end

  defp format_line({module, function, arity, [file: file, line: line]}) do
    "\t#{file}:#{line}:in `#{module}.#{function}/#{arity}'"
  end
end
