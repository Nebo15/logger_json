defmodule LoggerJSON.Formatter do
  @type opts :: [
          {:encoder_opts, encoder_opts()}
          | {:metadata, :all | {:all_except, [atom()]} | [atom()]}
          | {:redactors, [{module(), term()}]}
          | {atom(), term()}
        ]

  @type encoder_opts :: JSON.encoder() | [Jason.encode_opt()] | term()

  @callback format(event :: :logger.log_event(), opts :: opts()) :: iodata()

  @encoder Application.compile_env(:logger_json, :encoder, Jason)
  @encoder_protocol Application.compile_env(:logger_json, :encoder_protocol) || Module.concat(@encoder, "Encoder")
  @default_encoder_opts if(@encoder == JSON, do: &JSON.protocol_encode/2, else: [])

  @doc false
  @spec default_encoder_opts :: encoder_opts()
  def default_encoder_opts, do: @default_encoder_opts

  @doc false
  @spec encoder :: module()
  def encoder, do: @encoder

  @doc false
  @spec encoder_protocol :: module()
  def encoder_protocol, do: @encoder_protocol

  @doc false
  @spec require_jason_helpers :: Macro.t()
  defmacro require_jason_helpers do
    quote do
      require Jason.Helpers
    end
  end
end
