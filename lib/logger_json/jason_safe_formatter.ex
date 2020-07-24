defmodule LoggerJSON.JasonSafeFormatter do
  @moduledoc """
  Produces metadata that is "safe" for calling Jason.encode!() on without errors.
  This means that unexpected Logger metadata won't cause logging crashes.
  Current formatting is...
  - Maps: as is
  - Printable binaries: as is
  - Numbers: as is
  - Structs that don't implement Jason.Encoder: converted to maps
  - Tuples: converted to lists
  - Keyword lists: converted to Maps
  - everything else: inspected
  """
  def format(%Jason.Fragment{} = data) do
    data
  end

  def format(%mod{} = data) do
    if jason_implemented?(mod) do
      data
    else
      data
      |> Map.from_struct()
      |> format()
    end
  end

  def format(%{} = data) do
    for {key, value} <- data, into: %{}, do: {key, format(value)}
  end

  def format([{key, _} | _] = data) when is_atom(key) do
    Enum.into(data, %{}, fn
      {key, value} -> {key, format(value)}
    end)
  rescue
    _ -> for(d <- data, do: format(d))
  end

  def format({key, data}) when is_binary(key) or is_atom(key), do: %{key => format(data)}

  def format(data) when is_tuple(data), do: Tuple.to_list(data)

  def format(data) when is_number(data), do: data

  def format(data) when is_binary(data) do
    if String.valid?(data) && String.printable?(data) do
      data
    else
      inspect(data)
    end
  end

  def format(data) when is_list(data), do: for(d <- data, do: format(d))

  def format(data) do
    inspect(data, pretty: true, width: 80)
  end

  def jason_implemented?(mod) do
    try do
      :ok = Protocol.assert_impl!(Jason.Encoder, mod)
      true
    rescue
      ArgumentError ->
        false
    end
  end
end
