defmodule LoggerJSON.ParamsFilterTest do
  use ExUnit.Case, async: true

  alias LoggerJSON.ParamsFilter

  describe "discart_values" do
    test "in top level map" do
      values = %{"foo" => "bar", "password" => "should_not_show"}

      assert ParamsFilter.discard_values(values, ["password"]) ==
               %{"foo" => "bar", "password" => "[FILTERED]"}
    end

    test "when a map has secret key" do
      values = %{"foo" => "bar", "map" => %{"password" => "should_not_show"}}

      assert ParamsFilter.discard_values(values, ["password"]) ==
               %{"foo" => "bar", "map" => %{"password" => "[FILTERED]"}}
    end

    test "when a list has a map with secret" do
      values = %{"foo" => "bar", "list" => [%{"password" => "should_not_show"}]}

      assert ParamsFilter.discard_values(values, ["password"]) ==
               %{"foo" => "bar", "list" => [%{"password" => "[FILTERED]"}]}
    end

    test "does not filter structs" do
      values = %{"foo" => "bar", "file" => %Plug.Upload{}}

      assert ParamsFilter.discard_values(values, ["password"]) ==
               %{"foo" => "bar", "file" => %Plug.Upload{}}

      values = %{"foo" => "bar", "file" => %{__struct__: "s"}}

      assert ParamsFilter.discard_values(values, ["password"]) ==
               %{"foo" => "bar", "file" => %{:__struct__ => "s"}}
    end

    test "does not fail on atomic keys" do
      values = %{:foo => "bar", "password" => "should_not_show"}

      assert ParamsFilter.discard_values(values, ["password"]) ==
               %{:foo => "bar", "password" => "[FILTERED]"}
    end
  end
end
