defmodule CrashingGenServer do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call(:boom, _, _) do
    raise "boom"
  end
end
