defmodule Sequin.Sinks.NatsJetstream do
  @moduledoc false
  alias Sequin.Consumers.NatsJetstreamSink
  alias Sequin.Consumers.SinkConsumer
  alias Sequin.Error
  alias Sequin.Runtime.Routing.RoutedMessage

  @callback send_messages(SinkConsumer.t(), [RoutedMessage.t()]) ::
              :ok | {:error, Error.t()}
  @callback test_connection(NatsJetstreamSink.t()) :: :ok | {:error, Error.t()}
  @callback ensure_stream(NatsJetstreamSink.t()) :: :ok | {:error, Error.t()}

  @client Application.compile_env(:sequin, :nats_jetstream_module, Sequin.Sinks.Nats.JetstreamClient)
  defdelegate send_messages(consumer, messages), to: @client
  defdelegate test_connection(sink), to: @client
  defdelegate ensure_stream(sink), to: @client
end
