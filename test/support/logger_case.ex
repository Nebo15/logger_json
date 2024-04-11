defmodule Logger.Case do
  @moduledoc false
  use ExUnit.CaseTemplate
  import ExUnit.CaptureIO

  using _ do
    quote do
      import Logger.Case
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
      Jason.decode!(data)
    rescue
      _reason ->
        IO.puts(data)
        flunk("Failed to decode JSON")
    end
  end
end
