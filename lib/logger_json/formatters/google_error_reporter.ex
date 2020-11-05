defmodule LoggerJSON.Formatters.GoogleErrorReporter do
  require Logger
  @googleErrorType "type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent"

  def report(error, stacktrace, metadata \\ []) do
    [format_error(error, stacktrace) | Enum.map(stacktrace, &format_line/1)]
    |> Enum.filter(& &1)
    |> Enum.join("\n")
    |> Logger.error(Keyword.merge(["@type": @googleErrorType], metadata))
  end

  defp format_error(error, stacktrace) do
    normalized = Exception.normalize(:error, error, stacktrace)
    error_name = to_string(normalized.__struct__)
    "#{error_name}: #{Exception.message(normalized)}"
  end

  defp format_line({module, function, arity, [file: file, line: line]}) do
    "\t#{file}:#{line}:in `#{module}.#{function}/#{arity}'"
  end

  defp format_line({_, _, [], []}), do: nil
end
