defmodule LoggerJSON.Formatter.RedactorEncoder do
  @doc """
  Takes a term and makes sure that it can be encoded by the encoder without errors
  and without leaking sensitive information.

  ## Encoding rules

  Type                | Encoding                                            | Redaction
  ------------------- | --------------------------------------------------- | --------------
  `boolean()`         | unchanged                                           | unchanged
  `map()`             | unchanged                                           | values are redacted
  `list()`            | unchanged                                           | unchanged
  `tuple()`           | converted to list                                   | unchanged
  `binary()`          | unchanged if printable, otherwise using `inspect/2` | unchanged
  `number()`          | unchanged                                           | unchanged
  `atom()`            | unchanged                                           | unchanged
  `struct()`          | converted to map                                    | values are redacted
  `keyword()`         | converted to map                                    | values are redacted
  `%Jason.Fragment{}` | unchanged                                           | unchanged if encoder is `Jason`
  everything else     | using `inspect/2`                                   | unchanged
  """

  @type redactor :: {redactor :: module(), redactor_opts :: term()}

  @encoder_protocol LoggerJSON.Formatter.encoder_protocol()

  @spec encode(term(), redactors :: [redactor()]) :: term()
  def encode(nil, _redactors), do: nil
  def encode(true, _redactors), do: true
  def encode(false, _redactors), do: false
  def encode(atom, _redactors) when is_atom(atom), do: atom
  def encode(tuple, redactors) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> encode(redactors)
  def encode(number, _redactors) when is_number(number), do: number
  def encode("[REDACTED]", _redactors), do: "[REDACTED]"
  def encode(binary, _redactors) when is_binary(binary), do: encode_binary(binary)

  if @encoder_protocol == Jason.Encoder do
    def encode(fragment, _redactors) when is_struct(fragment, Jason.Fragment), do: fragment
  end

  def encode(%NaiveDateTime{} = naive_datetime, _redactors), do: naive_datetime
  def encode(%DateTime{} = datetime, _redactors), do: datetime
  def encode(%Date{} = date, _redactors), do: date
  def encode(%Time{} = time, _redactors), do: time

  if Code.ensure_loaded?(Decimal) do
    def encode(%Decimal{} = decimal, _redactors), do: decimal
  end

  def encode(%_struct{} = struct, redactors) do
    struct
    |> Map.from_struct()
    |> encode(redactors)
  end

  def encode(%{} = map, redactors) do
    for {key, value} <- map, into: %{} do
      encode_key_value({key, value}, redactors)
    end
  end

  def encode([{key, _} | _] = keyword, redactors) when is_atom(key) do
    Enum.into(keyword, %{}, fn {key, value} ->
      encode_key_value({key, value}, redactors)
    end)
  rescue
    _ -> encode_list(keyword, redactors, [])
  end

  def encode(list, redactors) when is_list(list), do: encode_list(list, redactors, [])
  def encode(data, _redactors), do: inspect(data, pretty: true, width: 80)

  defp encode_key_value({:mfa, {_module, _function, _arity} = mfa}, redactors) do
    value = format_mfa(mfa)
    encode_key_value({:mfa, value}, redactors)
  end

  defp encode_key_value({key, value}, redactors) do
    key = encode_key(key)
    {key, encode(redact(key, value, redactors), redactors)}
  end

  defp encode_key(key) when is_binary(key), do: encode_binary(key)
  defp encode_key(key) when is_atom(key) or is_number(key), do: key
  defp encode_key(key), do: inspect(key)

  defp format_mfa({module, function, arity}), do: "#{module}.#{function}/#{arity}"

  defp encode_binary(data) when is_binary(data) do
    if String.printable?(data) do
      data
    else
      inspect(data)
    end
  end

  defp redact(_key, value, []) do
    value
  end

  defp redact(key, value, redactors) do
    Enum.reduce(redactors, value, fn {redactor, opts}, acc ->
      redactor.redact(to_string(key), acc, opts)
    end)
  end

  defp encode_list([], _redactors, acc), do: Enum.reverse(acc)

  defp encode_list([head | tail], redactors, acc) do
    encoded = encode(head, redactors)
    encode_list(tail, redactors, [encoded | acc])
  end

  defp encode_list(improper_tail, redactors, [head | tail]) do
    # Tuple will be converted to list, which will make the list proper and
    # defeat the purpose
    redacted =
      case improper_tail do
        {key, value} -> {key, encode(redact(key, value, redactors), redactors)}
        _other -> encode(improper_tail, redactors)
      end

    tail
    |> Enum.reduce([head | redacted], fn el, acc -> [el | acc] end)
    |> inspect(limit: :infinity, pretty: true)
  end
end
