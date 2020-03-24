defmodule LoggerJSON.ParamsFilter do
  @moduledoc """
  Filter params by key replacing the content by `FILTERED`.
  Inspired by Phoenix implementation: https://github.com/phoenixframework/phoenix/blob/v1.4.16/lib/phoenix/logger.ex#L73-L91
  """

  def discard_values(%{__struct__: mod} = struct, _params) when is_atom(mod) do
    struct
  end

  def discard_values(%{} = map, params) do
    Enum.into(map, %{}, fn {k, v} ->
      if is_binary(k) and String.contains?(k, params) do
        {k, "[FILTERED]"}
      else
        {k, discard_values(v, params)}
      end
    end)
  end

  def discard_values([_ | _] = list, params) do
    Enum.map(list, &discard_values(&1, params))
  end

  def discard_values(other, _params), do: other
end
