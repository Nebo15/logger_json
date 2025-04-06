defmodule NameStruct do
  @moduledoc """
  This struct is required for tests on structs that implement the Jason.Encoder protocol.

  Defining this struct in the test module wouldn't work, since the .exs files
  are not compiled with the application so not protocol consolidation would happen.
  """

  @derive LoggerJSON.Formatter.encoder_protocol()

  defstruct [:name]
end
