if Code.ensure_loaded?(Jason) do
  # For certain crashes eg some structures containing PIDs that were not encoded properly
  # resulting in UndefinedProtocol crashes
  defimpl Jason.Encoder, for: PID do
    def encode(value, _opts) do
      value |> inspect() |> Jason.encode!()
    end
  end
end
