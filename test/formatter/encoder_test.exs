defmodule LoggerJSON.Formatter.EncoderTest do
  use Logger.Case, async: true
  use ExUnitProperties
  import LoggerJSON.Formatter.Encoder

  defmodule IDStruct, do: defstruct(id: nil)

  describe "encode/1" do
    test "allows nils" do
      assert encode(nil) == nil
    end

    test "allows booleans" do
      assert encode(true) == true
      assert encode(false) == false
    end

    test "allows printable strings" do
      assert encode("hello") == "hello"
    end

    test "inspects non-printable binaries" do
      assert encode("hello" <> <<0>>) == "<<104, 101, 108, 108, 111, 0>>"
    end

    test "allows atoms" do
      assert encode(:hello) == :hello
    end

    test "allows numbers" do
      assert encode(123) == 123
    end

    test "strips Structs" do
      assert %{id: "hello"} == encode(%IDStruct{id: "hello"})
    end

    test "does not strip structs for which Jason.Encoder is derived" do
      assert %NameStruct{name: "B"} == encode(%NameStruct{name: "B"})
    end

    test "converts tuples to lists" do
      assert encode({1, 2, 3}) == [1, 2, 3]
    end

    test "converts nested tuples to nested lists" do
      assert encode({{2000, 1, 1}, {13, 30, 15}}) == [[2000, 1, 1], [13, 30, 15]]
    end

    test "converts Keyword lists to maps" do
      assert encode(a: 1, b: 2) == %{a: 1, b: 2}
    end

    test "converts non-string map keys" do
      assert encode(%{1 => 2}) == %{1 => 2}
      assert encode(%{:a => 1}) == %{:a => 1}
      assert encode(%{{"a", "b"} => 1}) == %{"{\"a\", \"b\"}" => 1}
      assert encode(%{%{a: 1, b: 2} => 3}) == %{"%{a: 1, b: 2}" => 3}
      assert encode(%{[{:a, :b}] => 3}) == %{"[a: :b]" => 3}
    end

    test "inspects functions" do
      assert encode(&encode/1) == "&LoggerJSON.Formatter.Encoder.encode/1"
    end

    test "inspects pids" do
      assert encode(self()) == inspect(self())
    end

    test "doesn't choke on things that look like keyword lists but aren't" do
      assert encode([{:a, 1}, {:b, 2, :c}]) == [[:a, 1], [:b, 2, :c]]
    end

    test "formats nested structures" do
      input = %{
        foo: [
          foo_a: %{"x" => 1, "y" => %IDStruct{id: 1}},
          foo_b: [foo_b_1: 1, foo_b_2: {"2a", "2b"}]
        ],
        self: self()
      }

      assert encode(input) == %{
               foo: %{
                 foo_a: %{"x" => 1, "y" => %{id: 1}},
                 foo_b: %{foo_b_1: 1, foo_b_2: ["2a", "2b"]}
               },
               self: inspect(self())
             }
    end

    property "converts any term so that it can be encoded with Jason" do
      check all value <- term() do
        value
        |> encode()
        |> Jason.encode!()
      end
    end
  end
end
