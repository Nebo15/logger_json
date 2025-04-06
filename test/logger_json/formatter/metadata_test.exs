defmodule LoggerJSON.Formatter.MetadataTest do
  use ExUnit.Case, async: true
  import LoggerJSON.Formatter.Metadata

  describe "update_metadata_selector/2" do
    # test this
    #     def update_metadata_selector({:from_application_env, {app, module}, path}, processed_keys) do
    #   Application.fetch_env!(app, module)
    #   |> get_in(path)
    #   |> update_metadata_selector(processed_keys)
    # end

    # def update_metadata_selector({:from_application_env, {app, module}}, processed_keys) do
    #   Application.fetch_env!(app, module)
    #   |> update_metadata_selector(processed_keys)
    # end

    # def update_metadata_selector({:from_application_env, other}, _processed_keys) do
    #   raise """
    #   Invalid value for `:metadata` option: `{:from_application_env, #{inspect(other)}}`.

    #   The value must be a tuple with the application and module name,
    #   and an optional path to the metadata option.

    #   Eg.: `{:from_application_env, {:logger, :default_formatter}, [:metadata]}`
    #   """
    # end

    test "takes metadata from application env" do
      Application.put_env(:logger_json, :test_metadata_key, [:foo])

      assert update_metadata_selector({:from_application_env, {:logger_json, :test_metadata_key}}, []) ==
               [:foo]

      Application.put_env(:logger_json, :test_metadata_key, %{metadata: [:foo]})

      assert update_metadata_selector({:from_application_env, {:logger_json, :test_metadata_key}, [:metadata]}, []) ==
               [:foo]
    end

    test "raises if metadata is not a tuple with the application and module name" do
      message = ~r/Invalid value for `:metadata` option: `{:from_application_env, :foo}`./

      assert_raise ArgumentError, message, fn ->
        update_metadata_selector({:from_application_env, :foo}, [])
      end
    end

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
