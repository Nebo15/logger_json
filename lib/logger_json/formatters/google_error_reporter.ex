defmodule LoggerJSON.Formatters.GoogleErrorReporter do
  require Logger

  def format(error, stacktrace) do
    [format_error(error, stacktrace) | Enum.map(stacktrace, &format_line/1)]
    |> Enum.filter(& &1)
    |> Enum.join("\n")
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
