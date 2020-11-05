defmodule LoggerJSONGoogleErrorReporterTest do
  use Logger.Case, async: false
  alias LoggerJSON.Formatters.GoogleCloudLogger
  alias LoggerJSON.Formatters.GoogleErrorReporter

  setup do
    :ok =
      Logger.configure_backend(
        LoggerJSON,
        device: :user,
        level: nil,
        metadata: :all,
        json_encoder: Jason,
        on_init: :disabled,
        formatter: GoogleCloudLogger
      )

    :ok = Logger.reset_metadata([])
  end

  test "metadata" do
    log =
      capture_log(fn -> GoogleErrorReporter.report(%RuntimeError{message: "oops"}, []) end)
      |> Jason.decode!()

    assert log["severity"] == "ERROR"
    assert log["@type"] == "type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent"
  end

  test "google_error_reporter metadata" do
    :ok = Application.put_env(:logger_json, :google_error_reporter, service_context: [service: "myapp", version: "abc123"])
    log =
      capture_log(fn -> GoogleErrorReporter.report(%RuntimeError{message: "oops"}, []) end)
      |> Jason.decode!()

    assert log["serviceContext"]["service"] == "myapp"
    assert log["serviceContext"]["version"] == "abc123"
  after
    Application.delete_env(:logger_json, :google_error_reporter)
  end

  test "optional metadata" do
    log =
      capture_log(fn -> GoogleErrorReporter.report(%RuntimeError{message: "oops"}, [], foo: "bar") end)
      |> Jason.decode!()

    assert log["foo"] == "bar"
  end

  test "logs elixir error" do
    error = %RuntimeError{message: "oops"}

    stacktrace = [
      {Foo, :bar, 0, [file: 'foo/bar.ex', line: 123]},
      {Foo.Bar, :baz, 1, [file: 'foo/bar/baz.ex', line: 456]}
    ]

    log =
      capture_log(fn -> GoogleErrorReporter.report(error, stacktrace) end)
      |> Jason.decode!()

    assert log["message"] ==
             """
             Elixir.RuntimeError: oops
             \tfoo/bar.ex:123:in `Elixir.Foo.bar/0'
             \tfoo/bar/baz.ex:456:in `Elixir.Foo.Bar.baz/1'
             """
             |> String.trim_trailing()
  end

  test "logs erlang error" do
    error = :undef

    stacktrace = [
      {Foo, :bar, [], []},
      {Foo, :bar, 0, [file: 'foo/bar.ex', line: 123]},
      {Foo.Bar, :baz, 1, [file: 'foo/bar/baz.ex', line: 456]}
    ]

    log =
      capture_log(fn -> GoogleErrorReporter.report(error, stacktrace) end)
      |> Jason.decode!()

    assert log["message"] ==
             """
             Elixir.UndefinedFunctionError: function Foo.bar/0 is undefined (module Foo is not available)
             \tfoo/bar.ex:123:in `Elixir.Foo.bar/0'
             \tfoo/bar/baz.ex:456:in `Elixir.Foo.Bar.baz/1'
             """
             |> String.trim_trailing()
  end
end
