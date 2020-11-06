defmodule LoggerJSON.Formatters.GoogleErrorReporter do
  require Logger
  @googleErrorType "type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent"

  def report(kind, reason, stacktrace, metadata \\ []) do
    [format_banner(kind, reason, stacktrace) | format_stacktrace(stacktrace)]
    |> Enum.join("\n")
    |> Logger.error(Keyword.merge(build_metadata(), metadata))
  end

  defp format_banner(kind, reason, stacktrace) do
    Exception.format_banner(kind, reason, stacktrace)
  end

  defp format_stacktrace(stacktrace) do
    Exception.format_stacktrace(stacktrace)
    |> String.split("\n")
    |> Enum.map(&format_line/1)
  end

  defp format_line(line) do
    case Regex.run(~r/(.+)\:(\d+)\: (.*)/, line) do
      [_, file, line, function] -> "#{file}:#{line}:in `#{function}'"
      _ -> line
    end
  end

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
