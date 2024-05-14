defmodule LoggerJSON.Formatter.CodeTest do
  use ExUnit.Case, async: true
  import LoggerJSON.Formatter.Code

  describe "format_function/2" do
    test "returns the function name" do
      assert format_function(nil, "function") == "function"
    end

    test "returns the module and function name" do
      assert format_function("module", "function") == "module.function"
    end
  end

  describe "format_function/3" do
    test "returns the module, function name, and arity" do
      assert format_function("module", "function", 1) == "module.function/1"
    end
  end
end
