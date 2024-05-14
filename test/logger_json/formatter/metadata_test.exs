defmodule LoggerJSON.Formatter.MetadataTest do
  use ExUnit.Case, async: true
  import LoggerJSON.Formatter.Metadata

  describe "update_metadata_selector/2" do
    test "takes metadata :all rule and updates it to exclude the given keys" do
      assert update_metadata_selector(:all, [:ansi_color]) == {:all_except, [:ansi_color]}
    end

    test "takes metadata :all_except rule and returns a map with the given keys" do
      assert update_metadata_selector({:all_except, [:foo, :bar]}, [:bar, :buz]) ==
               {:all_except, [:foo, :bar, :bar, :buz]}
    end

    test "takes metadata keys and returns a map with the given keys" do
      assert update_metadata_selector([:foo, :bar], [:bar, :fiz]) == [:foo]
    end
  end

  describe "take_metadata/2" do
    test "takes metadata keys list and returns a map with the given keys" do
      meta = %{
        foo: "foo",
        bar: "bar",
        fiz: "fiz"
      }

      assert take_metadata(meta, [:foo, :bar]) == %{foo: "foo", bar: "bar"}
      assert take_metadata(meta, []) == %{}
    end

    test "takes metadata :all_except rule and returns a map with all keys except listed ones" do
      meta = %{
        foo: "foo",
        bar: "bar",
        fiz: "fiz"
      }

      assert take_metadata(meta, {:all_except, [:foo, :bar]}) == %{fiz: "fiz"}
    end

    test "takes metadata :all rule and returns a map with all keys" do
      meta = %{
        foo: "foo",
        bar: "bar",
        fiz: "fiz"
      }

      assert take_metadata(meta, :all) == meta
    end

    test "does not return reserved keys" do
      meta = %{
        ansi_color: "ansi_color",
        initial_call: "initial_call",
        crash_reason: "crash_reason",
        pid: "pid",
        gl: "gl",
        mfa: "mfa",
        report_cb: "report_cb",
        time: "time"
      }

      assert take_metadata(meta, :all) == %{}
      assert take_metadata(meta, {:all_except, [:foo]}) == %{}
    end

    test "returns reserved keys if they are listed explicitly" do
      meta = %{
        mfa: "mfa"
      }

      assert take_metadata(meta, [:mfa]) == %{mfa: "mfa"}
    end
  end
end
