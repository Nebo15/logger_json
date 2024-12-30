defmodule LoggerJSON.Case do
  @moduledoc false
  use ExUnit.CaseTemplate
  import ExUnit.CaptureIO

  @encoder LoggerJSON.Formatter.encoder()

  using _ do
    quote do
      import LoggerJSON.Case
    end
  end

  def capture_log(level \\ :debug, fun) do
    Logger.configure(level: level)

    capture_io(:user, fn ->
      fun.()
      Logger.flush()
    end)
  after
    Logger.configure(level: :debug)
  end

  def decode_or_print_error(data) do
    try do
      @encoder.decode!(data)
    rescue
      _reason ->
        IO.puts(data)
        flunk("Failed to decode JSON")
    end
  end
end
