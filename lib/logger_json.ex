defmodule LoggerJSON do
  @moduledoc """
  A collection of formatters and utilities for JSON-based logging for various cloud tools and platforms.

  ## Supported formatters

  * `LoggerJSON.Formatters.Basic` - a basic JSON formatter that logs messages in a structured format,
  can be used with any JSON-based logging system, like ElasticSearch, Logstash, etc.

  * `LoggerJSON.Formatters.GoogleCloud` - a formatter that logs messages in a structured format that can be
  consumed by Google Cloud Logger and Google Cloud Error Reporter.

  * `LoggerJSON.Formatters.Datadog` - a formatter that logs messages in a structured format that can be consumed
  by Datadog.

  * `LoggerJSON.Formatters.Elastic` - a formatter that logs messages in a structured format that conforms to the
  [Elastic Common Schema (ECS)](https://www.elastic.co/guide/en/ecs/8.11/ecs-reference.html),
  so it can be consumed by ElasticSearch, LogStash, FileBeat and Kibana.

  ## Installation

  Add `logger_json` to your list of dependencies in `mix.exs`:

      def deps do
        [
          # ...
          {:logger_json, "~> 6.0"}
          # ...
        ]
      end

  and install it running `mix deps.get`.

  Then, enable the formatter in your `config.exs`:

      config :logger, :default_handler,
        formatter: {LoggerJSON.Formatters.Basic, []}

  or during runtime (eg. in your `application.ex`):

      :logger.update_handler_config(:default, :formatter, {Basic, %{}})

  ## Configuration

  Configuration can be set using 2nd element of the tuple of the `:formatter` option in `Logger` configuration.
  For example in `config.exs`:

      config :logger, :default_handler,
        formatter: {LoggerJSON.Formatters.GoogleCloud, metadata: :all, project_id: "logger-101"}

  or during runtime:

      :logger.update_handler_config(:default, :formatter, {Basic, %{metadata: {:all_except, [:conn]}}})

  ### Shared Options

  Some formatters require additional configuration options. Here are the options that are common for each formatter:

    * `:metadata` - a list of metadata keys to include in the log entry. By default, no metadata is included.
    If `:all`is given, all metadata is included. If `{:all_except, keys}` is given, all metadata except
    the specified keys is included.

    * `:redactors` - a list of tuples, where first element is the module that implements the `LoggerJSON.Redactor` behaviour,
    and the second element is the options to pass to the redactor module. By default, no redactors are used.

  ## Metadata

  You can set some well-known metadata keys to be included in the log entry. The following keys are supported
  for all formatters:

    * `:conn` - the `Plug.Conn` struct, setting it will include the request and response details in the log entry;
    * `:crash_reason` - a tuple where the first element is the exception struct and the second is the stacktrace.
    For example: `Logger.error("Exception!", crash_reason: {e, __STACKTRACE__})`. Setting it will include the exception
    details in the log entry.

  Formatters may encode the well-known metadata differently and support additional metadata keys, see the documentation
  of the formatter for more details.
  """
  @log_levels [:error, :info, :debug, :emergency, :alert, :critical, :warning, :notice]
  @log_level_strings Enum.map(@log_levels, &to_string/1)

  @doc """
  Configures Logger log level at runtime by using value from environment variable.

  By default, 'LOG_LEVEL' environment variable is used.
  """
  def configure_log_level_from_env!(env_name \\ "LOG_LEVEL") do
    env_name
    |> System.get_env()
    |> configure_log_level!()
  end

  @doc """
  Changes Logger log level at runtime.

  Notice that settings this value below `compile_time_purge_level` would not work,
  because Logger calls would be already stripped at compile-time.
  """
  def configure_log_level!(nil),
    do: :ok

  def configure_log_level!(level) when level in @log_level_strings,
    do: Logger.configure(level: String.to_atom(level))

  def configure_log_level!(level) when level in @log_levels,
    do: Logger.configure(level: level)

  def configure_log_level!(level) do
    raise ArgumentError, "Log level should be one of 'debug', 'info', 'warn', 'error' values, got: #{inspect(level)}"
  end
end
