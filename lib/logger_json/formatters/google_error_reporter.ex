defmodule LoggerJSON.Formatters.GoogleErrorReporter do
  require Logger
  @googleErrorType "type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent"

  def report(error, stacktrace, metadata \\ []) do
    [format_banner(error, stacktrace) | format_stacktrace(stacktrace)]
    |> Enum.join("\n")
    |> Logger.error(Keyword.merge(build_metadata(), metadata))
  end

  defp format_banner(error, stacktrace) do
    formatted = Exception.format_banner(:error, error, stacktrace)
    case Regex.run(~r/\*\* \((\S+)\)(.*)/, formatted) do
      [_, type, message] -> "#{type}:#{message}"
      _ -> error
    end
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
