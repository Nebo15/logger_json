# LoggerJSON

[![Build Status](https://github.com/Nebo15/logger_json/actions/workflows/ci.yml/badge.svg)](https://github.com/Nebo15/logger_json/actions/workflows/ci.yml)
[![Coverage Status](https://coveralls.io/repos/github/Nebo15/logger_json/badge.svg?branch=master)](https://coveralls.io/github/Nebo15/logger_json?branch=master)
[![Module Version](https://img.shields.io/hexpm/v/logger_json.svg)](https://hex.pm/packages/logger_json)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/logger_json/)
[![Hex Download Total](https://img.shields.io/hexpm/dt/logger_json.svg)](https://hex.pm/packages/logger_json)
[![License](https://img.shields.io/hexpm/l/logger_json.svg)](https://github.com/Nebo15/logger_json/blob/master/LICENSE.md)

A collection of formatters and utilities for JSON-based logging for various cloud tools and platforms.

## Supported formatters

- [`LoggerJSON.Formatters.Basic`](https://hexdocs.pm/logger_json/LoggerJSON.Formatters.Basic.html) - a basic JSON formatter that logs messages in a structured, but generic format, can be used with any JSON-based logging system.

- [`LoggerJSON.Formatters.GoogleCloud`](https://hexdocs.pm/logger_json/LoggerJSON.Formatters.GoogleCloud.html) - a formatter that logs messages in a structured format that can be consumed by Google Cloud Logger and Google Cloud Error Reporter.

- [`LoggerJSON.Formatters.Datadog`](https://hexdocs.pm/logger_json/LoggerJSON.Formatters.Datadog.html) - a formatter that logs messages in a structured format that can be consumed by Datadog.

- [`LoggerJSON.Formatters.Elastic`](https://hexdocs.pm/logger_json/LoggerJSON.Formatters.Elastic.html) - a formatter that logs messages in a structured format that conforms to the [Elastic Common Schema (ECS)](https://www.elastic.co/guide/en/ecs/8.11/ecs-reference.html), so it can be consumed by ElasticSearch, LogStash, FileBeat and Kibana.

## Installation

Add `logger_json` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    # ...
    {:logger_json, "~> 7.0"}
    # ...
  ]
end
```

and install it running `mix deps.get`.

Then, enable the formatter in your `runtime.exs`:

```elixir
config :logger, :default_handler,
  formatter: LoggerJSON.Formatters.Basic.new(metadata: [:request_id])
```

or inside your application code (eg. in your `application.ex`):

```elixir
formatter = LoggerJSON.Formatters.Basic.new(metadata: :all)
:logger.update_handler_config(:default, :formatter, formatter)
```

or inside your `config.exs` (notice that `new/1` is not available here
and tuple format must be used):

```elixir
config :logger, :default_handler,
  formatter: {LoggerJSON.Formatters.Basic, metadata: [:request_id]}
```

You might also want to format the log messages when migrations are running:

```elixir
config :domain, MyApp.Repo,
  # ...
  start_apps_before_migration: [:logger_json]
```

And you might want to make logging level configurable using an `LOG_LEVEL` environment variable (in `application.ex`):

```elixir
LoggerJSON.configure_log_level_from_env!()
```

Additionally, you may also be try [redirecting otp reports to Logger](https://hexdocs.pm/logger/Logger.html#module-configuration) (see "Configuration" section).

## Configuration

Configuration can be set using 2nd element of the tuple of the `:formatter` option in `Logger` configuration.
For example in `runtime.exs`:

```elixir
config :logger, :default_handler,
  formatter: LoggerJSON.Formatters.GoogleCloud.new(metadata: :all, project_id: "logger-101")
```

or during runtime:

```elixir
formatter = LoggerJSON.Formatters.Basic.new(%{metadata: {:all_except, [:conn]}})
:logger.update_handler_config(:default, :formatter, formatter)
```

By default, `LoggerJSON` is using `Jason` as the JSON encoder. If you use Elixir 1.18 or later, you can
use the built-in `JSON` module as the encoder. To do this, you need to set the `:encoder` option in your
`config.exs` file. This setting is only available at compile-time:

    config :logger_json, encoder: JSON

## Docs

The docs can be found at [https://hexdocs.pm/logger_json](https://hexdocs.pm/logger_json).

## Examples

### Basic

```json
{
  "message": "Hello",
  "metadata": {
    "domain": ["elixir"]
  },
  "severity": "notice",
  "time": "2024-04-11T21:31:01.403Z"
}
```

### Google Cloud Logger

Follows the [Google Cloud Logger LogEntry](https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry) format,
for more details see [special fields in structured payloads](https://cloud.google.com/logging/docs/agent/configuration#special_fields_in_structured_payloads).

```json
{
  "logging.googleapis.com/trace": "projects/my-projectid/traces/0679686673a",
  "logging.googleapis.com/spanId": "000000000000004a",
  "logging.googleapis.com/operation": {
    "pid": "#PID<0.29081.0>"
  },
  "logging.googleapis.com/sourceLocation": {
    "file": "/Users/andrew/Projects/os/logger_json/test/formatters/google_cloud_test.exs",
    "function": "Elixir.LoggerJSON.Formatters.GoogleCloudTest.test logs an LogEntry of a given level/1",
    "line": 44
  },
  "message": {
    "domain": ["elixir"],
    "message": "Hello"
  },
  "severity": "NOTICE",
  "time": "2024-04-12T15:07:55.020Z"
}
```

and this is how it looks in Google Cloud Logger:

```json
{
  "insertId": "1d4hmnafsj7vy1",
  "jsonPayload": {
    "message": "Hello",
    "logging.googleapis.com/spanId": "000000000000004a",
    "domain": ["elixir"],
    "time": "2024-04-12T15:07:55.020Z"
  },
  "resource": {
    "type": "gce_instance",
    "labels": {
      "zone": "us-east1-d",
      "project_id": "firezone-staging",
      "instance_id": "3168853301020468373"
    }
  },
  "timestamp": "2024-04-12T15:07:55.023307594Z",
  "severity": "NOTICE",
  "logName": "projects/firezone-staging/logs/cos_containers",
  "operation": {
    "id": "F8WQ1FsdFAm5ZY0AC1PB",
    "producer": "#PID<0.29081.0>"
  },
  "trace": "projects/firezone-staging/traces/bc007e40a2e9edffa23785d8badc43b8",
  "sourceLocation": {
    "file": "lib/phoenix/logger.ex",
    "line": "231",
    "function": "Elixir.Phoenix.Logger.phoenix_endpoint_stop/4"
  },
  "receiveTimestamp": "2024-04-12T15:07:55.678986520Z"
}
```

Exception that can be sent to Google Cloud Error Reporter:

```json
{
  "httpRequest": {
    "protocol": "HTTP/1.1",
    "referer": "http://www.example.com/",
    "remoteIp": "",
    "requestMethod": "PATCH",
    "requestUrl": "http://www.example.com/",
    "status": 503,
    "userAgent": "Mozilla/5.0"
  },
  "logging.googleapis.com/operation": {
    "pid": "#PID<0.250.0>"
  },
  "logging.googleapis.com/sourceLocation": {
    "file": "/Users/andrew/Projects/os/logger_json/test/formatters/google_cloud_test.exs",
    "function": "Elixir.LoggerJSON.Formatters.GoogleCloudTest.test logs exception http context/1",
    "line": 301
  },
  "@type": "type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent",
  "context": {
    "httpRequest": {
      "protocol": "HTTP/1.1",
      "referer": "http://www.example.com/",
      "remoteIp": "",
      "requestMethod": "PATCH",
      "requestUrl": "http://www.example.com/",
      "status": 503,
      "userAgent": "Mozilla/5.0"
    },
    "reportLocation": {
      "filePath": "/Users/andrew/Projects/os/logger_json/test/formatters/google_cloud_test.exs",
      "functionName": "Elixir.LoggerJSON.Formatters.GoogleCloudTest.test logs exception http context/1",
      "lineNumber": 301
    }
  },
  "domain": ["elixir"],
  "message": "Hello",
  "serviceContext": {
    "service": "nonode@nohost"
  },
  "stack_trace": "** (EXIT from #PID<0.250.0>) :foo",
  "severity": "DEBUG",
  "time": "2024-04-11T21:34:53.503Z"
}
```

## Datadog

Adheres to the [default standard attribute list](https://docs.datadoghq.com/logs/processing/attributes_naming_convention/#default-standard-attribute-list)
as much as possible.

```json
{
  "domain": ["elixir"],
  "http": {
    "method": "GET",
    "referer": "http://www.example2.com/",
    "request_id": null,
    "status_code": 200,
    "url": "http://www.example.com/",
    "url_details": {
      "host": "www.example.com",
      "path": "/",
      "port": 80,
      "queryString": "",
      "scheme": "http"
    },
    "useragent": "Mozilla/5.0"
  },
  "logger": {
    "file_name": "/Users/andrew/Projects/os/logger_json/test/formatters/datadog_test.exs",
    "line": 239,
    "method_name": "Elixir.LoggerJSON.Formatters.DatadogTest.test logs http context/1",
    "thread_name": "#PID<0.225.0>"
  },
  "message": "Hello",
  "network": {
    "client": {
      "ip": "127.0.0.1"
    }
  },
  "syslog": {
    "hostname": "MacBook-Pro",
    "severity": "debug",
    "timestamp": "2024-04-11T23:10:47.967Z"
  }
}
```

## Elastic

Follows the [Elastic Common Schema (ECS)](https://www.elastic.co/guide/en/ecs/8.11/ecs-reference.html) format.

```json
{
  "@timestamp": "2024-05-21T15:17:35.374Z",
  "ecs.version": "8.11.0",
  "log.level": "info",
  "log.logger": "Elixir.LoggerJSON.Formatters.ElasticTest",
  "log.origin": {
    "file.line": 18,
    "file.name": "/app/logger_json/test/logger_json/formatters/elastic_test.exs",
    "function": "test logs message of every level/1"
  },
  "message": "Hello"
}
```

When an error is thrown, the message field is populated with the error message and the `error.` fields will be set:

> Note: when throwing a custom exception type that defines the fields `id` and/or `code`, then the `error.id` and/or `error.code` fields will be set respectively.

```json
{
  "@timestamp": "2024-05-21T15:20:11.623Z",
  "ecs.version": "8.11.0",
  "error.message": "runtime error",
  "error.stack_trace": "** (RuntimeError) runtime error\n    test/logger_json/formatters/elastic_test.exs:191: anonymous fn/0 in LoggerJSON.Formatters.ElasticTest.\"test logs exceptions\"/1\n",
  "error.type": "Elixir.RuntimeError",
  "log.level": "error",
  "message": "runtime error"
}
```

Any custom metadata fields will be added to the root of the message, so that your application can fill any other ECS fields that you require:

> Note that this also allows you to produce messages that do not strictly adhere to the ECS specification.

```json
// Logger.info("Hello") with Logger.metadata(:"device.model.name": "My Awesome Device")
// or Logger.info("Hello", "device.model.name": "My Awesome Device")
{
  "@timestamp": "2024-05-21T15:17:35.374Z",
  "ecs.version": "8.11.0",
  "log.level": "info",
  "log.logger": "Elixir.LoggerJSON.Formatters.ElasticTest",
  "log.origin": {
    "file.line": 18,
    "file.name": "/app/logger_json/test/logger_json/formatters/elastic_test.exs",
    "function": "test logs message of every level/1"
  },
  "message": "Hello",
  "device.model.name": "My Awesome Device"
}
```

## Copyright and License

Copyright (c) 2016 Andrew Dryga

Released under the MIT License, which can be found in [LICENSE.md](./LICENSE.md).
