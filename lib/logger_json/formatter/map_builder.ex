defmodule LoggerJSON.Formatter.MapBuilder do
  @doc """
  Optionally put a value to a map.
  """
  def maybe_put(map, _key, nil), do: map
  def maybe_put(map, key, value), do: Map.put(map, key, value)

  @doc """
  Optionally merge two maps.
  """
  def maybe_merge(map, nil), do: map
  def maybe_merge(left_map, right_map), do: Map.merge(right_map, left_map)
end
