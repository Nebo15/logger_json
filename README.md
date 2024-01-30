# LoggerJSON

[![Build Status](https://travis-ci.org/Nebo15/logger_json.svg?branch=master)](https://travis-ci.org/Nebo15/logger_json)
[![Coverage Status](https://coveralls.io/repos/github/Nebo15/logger_json/badge.svg?branch=master)](https://coveralls.io/github/Nebo15/logger_json?branch=master)
[![Module Version](https://img.shields.io/hexpm/v/logger_json.svg)](https://hex.pm/packages/logger_json)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/logger_json/)
[![Hex Download Total](https://img.shields.io/hexpm/dt/logger_json.svg)](https://hex.pm/packages/logger_json)
[![License](https://img.shields.io/hexpm/l/logger_json.svg)](https://github.com/Nebo15/logger_json/blob/master/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/Nebo15/logger_json.svg)](https://github.com/Nebo15/logger_json/commits/master)

JSON console back-end for Elixir Logger.

It can be used as drop-in replacement for default `:console` Logger back-end in cases where you use Google Cloud Logger, DataDog or other JSON-based log collectors. After adding this back-end you may also be interested in [redirecting otp and sasl reports to Logger](https://hexdocs.pm/logger/Logger.html#error-logger-configuration) (see "Error Logger configuration" section).

Minimum supported Erlang/OTP version is 20.

## Log Format

LoggerJSON provides three JSON formatters out of the box and allows developers to implement a custom one.

### BasicLogger

The `LoggerJSON.Formatters.BasicLogger` formatter provides a generic JSON formatted message with no vendor specific entries in the payload. A sample log entry from `LoggerJSON.Formatters.BasicLogger` looks like the following:

```json
{
  "time": "2020-04-02T11:59:06.710Z",
  "severity": "debug",
  "message": "hello",
  "metadata": {
    "user_id": 13
  }
}
```

### GoogleCloudLogger

Generates JSON that is compatible with the [Google Cloud Logger LogEntry](https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry) format:

```json
{
  "message": "hello",
  "logging.googleapis.com/sourceLocation": {
    "file": "/os/logger_json/test/unit/logger_json_test.exs",
    "function": "Elixir.LoggerJSONGoogleTest.test metadata can be configured/1",
    "line": 71
  },
  "severity": "DEBUG",
  "time": "2018-10-19T01:10:49.582Z",
  "user_id": 13
}
```

Notice that GKE doesn't allow to set certain fields of the LogEntry, so support is limited. The results in Google Cloud Logger would looks something like this:

```json
{
  "httpRequest": {
    "latency": "0.350s",
    "remoteIp": "::ffff:10.142.0.2",
    "requestMethod": "GET",
    "requestPath": "/",
    "requestUrl": "http://10.16.0.70/",
    "status": 200,
    "userAgent": "kube-probe/1.10+"
  },
  "insertId": "1g64u74fgmqqft",
  "jsonPayload": {
    "message": "",
    "phoenix": {
      "action": "index",
      "controller": "Elixir.MyApp.Web.PageController"
    },
    "request_id": "2lfbl1r3m81c40e5v40004c2",
    "vm": {
      "hostname": "myapp-web-66979fc-vbk4q",
      "pid": 1
    }
  },
  "logName": "projects/hammer-staging/logs/stdout",
  "metadata": {
    "systemLabels": {},
    "userLabels": {}
  },
  "operation": {
    "id": "2lfbl1r3m81c40e5v40004c2"
  },
  "receiveTimestamp": "2018-10-18T14:33:35.515253723Z",
  "resource": {},
  "severity": "INFO",
  "sourceLocation": {
    "file": "iex",
    "function": "Elixir.LoggerJSON.Plug.call/2",
    "line": "36"
  },
  "timestamp": "2018-10-18T14:33:33.263Z"
}
```

### DatadogLogger

Adheres to the [default standard attribute list](https://docs.datadoghq.com/logs/processing/attributes_naming_convention/#default-standard-attribute-list).

```json
{
  "domain": ["elixir"],
  "duration": 3863403,
  "http": {
    "url": "http://localhost/create-account",
    "status_code": 200,
    "method": "GET",
    "referer": "http://localhost:4000/login",
    "request_id": "http_FlDCOItxeudZJ20AAADD",
    "useragent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.66 Safari/537.36",
    "url_details": {
      "host": "localhost",
      "port": 4000,
      "path": "/create-account",
      "queryString": "",
      "scheme": "http"
    }
  },
  "logger": {
    "thread_name": "#PID<0.1042.0>",
    "method_name": "Elixir.LoggerJSON.Plug.call/2"
  },
  "message": "",
  "network": {
    "client": {
      "ip": "127.0.0.1"
    }
  },
  "phoenix": {
    "controller": "Elixir.RecognizerWeb.Accounts.UserRegistrationController",
    "action": "new"
  },
  "request_id": "http_FlDCOItxeudZJ20AAADD",
  "syslog": {
    "hostname": [10, 10, 100, 100, 100, 100, 100],
    "severity": "info",
    "timestamp": "2020-12-14T19:16:55.088Z"
  }
}
```

### Custom formatters

You can change this structure by implementing `LoggerJSON.Formatter` behaviour and passing module
name to `:formatter` config option. Example module can be found in `LoggerJSON.Formatters.GoogleCloudLogger`.

```ex
config :logger_json, :backend,
  formatter: MyFormatterImplementation
```

## Installation

It's [available on Hex](https://hex.pm/packages/logger_json), the package can be installed as:

1. Add `:logger_json` to your list of dependencies in `mix.exs`:

```ex
def deps do
  [{:logger_json, "~> 5.1"}]
end
```

2. Set configuration in your `config/config.exs`:

```ex
config :logger_json, :backend,
  metadata: :all,
  json_encoder: Jason,
  formatter: LoggerJSON.Formatters.GoogleCloudLogger

```

Some integrations (for eg. Plug) use `metadata` to log request and response parameters. You can reduce log size by replacing `:all` (which means log all metadata) with a list of the ones that you actually need.

Beware that LoggerJSON always ignores [some metadata keys](https://github.com/Nebo15/logger_json/blob/349c8174886135a02bb16317f76beac89d1aa20d/lib/logger_json.ex#L46), but formatters like `GoogleCloudLogger` and `DatadogLogger` still persist those metadata values into a structured output. This behavior is similar to the default Elixir logger backend.

3. Replace default Logger `:console` back-end with `LoggerJSON`:

```ex
config :logger,
  backends: [LoggerJSON]
```

4. Optionally. Log requests and responses by replacing a `Plug.Logger` in your endpoint with a:

```ex
plug LoggerJSON.Plug
```

`LoggerJSON.Plug` is configured by default to use `LoggerJSON.Plug.MetadataFormatters.GoogleCloudLogger`.
You can replace it with the `:metadata_formatter` config option.

5. Optionally. Use Ecto telemetry for additional metadata:

Attach telemetry handler for Ecto events in `start/2` function in `application.ex`

```ex
:ok =
  :telemetry.attach(
    "logger-json-ecto",
    [:my_app, :repo, :query],
    &LoggerJSON.Ecto.telemetry_logging_handler/4,
    :debug
  )
```

Prevent duplicate logging of events, by setting `log` configuration option to `false`

```ex
config :my_app, MyApp.Repo,
  adapter: Ecto.Adapters.Postgres,
  log: false
```

## Dynamic configuration

For dynamically configuring the endpoint, such as loading data
from environment variables or configuration files, LoggerJSON provides
an `:on_init` option that allows developers to set a module, function
and list of arguments that is invoked when the endpoint starts.

```ex
config :logger_json, :backend,
  on_init: {YourApp.Logger, :load_from_system_env, []}
```

## Encoders support

You can replace default Jason encoder with other module that supports `encode_to_iodata!/1` function and
encoding fragments.

## Documentation

The docs can be found at [https://hexdocs.pm/logger_json](https://hexdocs.pm/logger_json)

## Thanks

Many source code has been taken from original Elixir Logger `:console` back-end source code, so I want to thank all it's authors and contributors.

Part of `LoggerJSON.Plug` module have origins from `plug_logger_json` by @bleacherreport,
originally licensed under Apache License 2.0. Part of `LoggerJSON.PlugTest` are from Elixir's Plug licensed under Apache 2.

## Copyright and License

Copyright (c) 2016 Nebo #15

Released under the MIT License, which can be found in [LICENSE.md](./LICENSE.md).
