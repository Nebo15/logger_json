defmodule LoggerJSON.FormatterTest do
  use LoggerJSON.Case, async: true

  require LoggerJSON.Formatter

  @encoder Application.compile_env!(:logger_json, :encoder)
  @encoder_protocol Module.concat(@encoder, "Encoder")
  @default_encoder_opts if(@encoder == JSON, do: &JSON.protocol_encode/2, else: [])

  describe "default_encoder_opts/0" do
    test "returns value based on :encoder env" do
      assert LoggerJSON.Formatter.default_encoder_opts() == @default_encoder_opts
    end
  end

  describe "encoder/0" do
    test "returns value based on :encoder env" do
      assert LoggerJSON.Formatter.encoder() == @encoder
    end
  end

  describe "encoder_protocol/0" do
    test "returns value based on :encoder env" do
      assert LoggerJSON.Formatter.encoder_protocol() == @encoder_protocol
    end
  end

  describe "with/2" do
    test "runs do block if it matches encoder" do
      result =
        LoggerJSON.Formatter.with @encoder do
          quote do
            :ok
          end
        else
          quote do
            :error
          end
        end

      assert result == :ok
    end

    test "runs else block if it does not match encoder" do
      result =
        LoggerJSON.Formatter.with Something do
          quote do
            :error
          end
        else
          quote do
            :ok
          end
        end

      assert result == :ok
    end
  end
end
