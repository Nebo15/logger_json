defmodule LoggerJSON.Formatter.Encoder do
  @moduledoc """
  Utilities for converting metadata into data structures that can be safely passed to `Jason.encode!/1`.
  """

  @doc """
  Produces metadata that is "safe" for calling Jason.encode!/1 on without errors.
  This means that unexpected Logger metadata won't cause logging crashes.

  Current formatting is...
    * Maps: as is
    * Printable binaries: as is
    * Numbers: as is
    * Structs that don't implement Jason.Encoder: converted to maps
    * Tuples: converted to lists
    * Keyword lists: converted to Maps
    * everything else: inspected
  """
  @spec encode(any()) :: any()
  def encode(nil), do: nil
  def encode(true), do: true
  def encode(false), do: false
  def encode(atom) when is_atom(atom), do: atom
  def encode(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> encode()
  def encode(number) when is_number(number), do: number
  def encode(binary) when is_binary(binary), do: encode_binary(binary)
  def encode(%Jason.Fragment{} = fragment), do: fragment

  def encode(%_struct{} = struct) do
    if protocol_implemented?(struct) do
      struct
    else
      struct
      |> Map.from_struct()
      |> encode()
    end
  end

  def encode(%{} = map) do
    for {key, value} <- map, into: %{}, do: {encode_map_key(key), encode(value)}
  end

  def encode([{key, _} | _] = keyword) when is_atom(key) do
    Enum.into(keyword, %{}, fn
      {key, value} -> {encode_map_key(key), encode(value)}
    end)
  rescue
    _ -> for(el <- keyword, do: encode(el))
  end

  def encode(list) when is_list(list), do: for(el <- list, do: encode(el))
  def encode({key, data}) when is_binary(key) or is_atom(key), do: %{encode_map_key(key) => encode(data)}
  def encode(data), do: inspect(data, pretty: true, width: 80)

  defp encode_map_key(key) when is_binary(key), do: encode_binary(key)
  defp encode_map_key(key) when is_atom(key) or is_number(key), do: key
  defp encode_map_key(key), do: inspect(key)

  defp encode_binary(data) when is_binary(data) do
    if String.valid?(data) && String.printable?(data) do
      data
    else
      inspect(data)
    end
  end

  def protocol_implemented?(data) do
    impl = Jason.Encoder.impl_for(data)
    impl && impl != Jason.Encoder.Any
  end
end
