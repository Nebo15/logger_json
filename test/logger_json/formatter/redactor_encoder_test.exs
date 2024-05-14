defmodule LoggerJSON.Formatter.RedactorEncoderTest do
  use LoggerJSON.Case, async: true
  use ExUnitProperties
  import LoggerJSON.Formatter.RedactorEncoder

  defmodule IDStruct, do: defstruct(id: nil)

  defmodule PasswordStruct, do: defstruct(password: "foo")

  @redactors [{LoggerJSON.Redactors.RedactKeys, ["password"]}]

  describe "encode/2" do
    test "allows nils" do
      assert encode(nil, @redactors) == nil
    end

    test "allows booleans" do
      assert encode(true, @redactors) == true
      assert encode(false, @redactors) == false
    end

    test "allows printable strings" do
      assert encode("hello", @redactors) == "hello"
    end

    test "inspects non-printable binaries" do
      assert encode("hello" <> <<0>>, @redactors) == "<<104, 101, 108, 108, 111, 0>>"
    end

    test "allows atoms" do
      assert encode(:hello, @redactors) == :hello
    end

    test "allows numbers" do
      assert encode(123, @redactors) == 123
    end

    test "strips Structs" do
      assert encode(%IDStruct{id: "hello"}, @redactors) == %{id: "hello"}
    end

    test "redacts values in structs" do
      assert encode(%PasswordStruct{password: "hello"}, @redactors) == %{password: "[REDACTED]"}
    end

    # Jason.Encoder protocol can be used in many other scenarios,
    # like DB/API response serliazation, so it's better not to
    # assume that it's what the users expects to see in logs.
    test "strips structs when Jason.Encoder is derived for them" do
      assert encode(%NameStruct{name: "B"}, @redactors) == %{name: "B"}
    end

    test "converts tuples to lists" do
      assert encode({1, 2, 3}, @redactors) == [1, 2, 3]
    end

    test "converts nested tuples to nested lists" do
      assert encode({{2000, 1, 1}, {13, 30, 15}}, @redactors) == [[2000, 1, 1], [13, 30, 15]]
    end

    test "converts keyword lists to maps" do
      assert encode([a: 1, b: 2], @redactors) == %{a: 1, b: 2}
    end

    test "redacts values in keyword lists" do
      assert encode([password: "foo"], @redactors) == %{password: "[REDACTED]"}
    end

    test "converts non-string map keys" do
      assert encode(%{1 => 2}, []) == %{1 => 2}
      assert encode(%{:a => 1}, []) == %{:a => 1}
      assert encode(%{{"a", "b"} => 1}, []) == %{"{\"a\", \"b\"}" => 1}
      assert encode(%{%{a: 1, b: 2} => 3}, []) == %{"%{a: 1, b: 2}" => 3}
      assert encode(%{[{:a, :b}] => 3}, []) == %{"[a: :b]" => 3}
    end

    test "redacts values in maps" do
      assert encode(%{password: "foo"}, @redactors) == %{password: "[REDACTED]"}
    end

    test "inspects functions" do
      assert encode(&encode/2, []) == "&LoggerJSON.Formatter.RedactorEncoder.encode/2"
    end

    test "inspects pids" do
      assert encode(self(), []) == inspect(self())
    end

    test "doesn't choke on things that look like keyword lists but aren't" do
      assert encode([{:a, 1}, {:b, 2, :c}], []) == [[:a, 1], [:b, 2, :c]]
    end

    test "formats nested structures" do
      input = %{
        foo: [
          foo_a: %{"x" => 1, "y" => %IDStruct{id: 1}},
          foo_b: [foo_b_1: 1, foo_b_2: {"2a", "2b"}]
        ],
        self: self()
      }

      assert encode(input, []) == %{
               foo: %{
                 foo_a: %{"x" => 1, "y" => %{id: 1}},
                 foo_b: %{foo_b_1: 1, foo_b_2: ["2a", "2b"]}
               },
               self: inspect(self())
             }
    end

    test "redacts nested structures" do
      assert encode(%{password: "foo", other_key: %{password: ["foo"]}}, @redactors) == %{
               password: "[REDACTED]",
               other_key: %{password: "[REDACTED]"}
             }

      assert encode([password: "foo", other_key: [password: "bar"]], @redactors) == %{
               password: "[REDACTED]",
               other_key: %{password: "[REDACTED]"}
             }

      assert encode([password: "foo", other_key: %{password: "bar"}], @redactors) == %{
               password: "[REDACTED]",
               other_key: %{password: "[REDACTED]"}
             }

      assert encode([foo: ["foo", %{password: "bar"}]], @redactors) == %{foo: ["foo", %{password: "[REDACTED]"}]}
    end

    property "converts any term so that it can be encoded with Jason" do
      check all value <- term() do
        value
        |> encode([])
        |> Jason.encode!()
      end
    end
  end
end
