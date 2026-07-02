defmodule LoggerJSON.FormatterTest do
  use LoggerJSON.Case, async: true

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
end
