defmodule LoggerJSON.Formatter.Code do
  @moduledoc false

  @doc """
  Provide a string output of the MFA log entry.
  """
  def format_function(nil, function), do: function
  def format_function(module, function), do: "#{module}.#{function}"
  def format_function(module, function, arity), do: "#{format_function(module, function)}/#{arity}"
end
