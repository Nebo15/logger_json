defmodule LoggerJSON.Redactor do
  @moduledoc """
  This module provides a behaviour which allows to redact sensitive information from logs.

  *Note*: redactor will not be applied on `Jason.Fragment` structs if the encoder is `Jason`.
  For more information about encoding and redacting see `LoggerJSON.Formatter.RedactorEncoder.encode/2`.
  """

  @doc """
  Takes a key and a value and returns a redacted value.

  This callback will be applied on key-value pairs, like elements of structs, maps or keyword lists.
  """
  @callback redact(key :: String.t(), value :: term(), opts :: term()) :: term()
end
